import os
import requests
from github import Github

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_BASE = "https://openrouter.ai/api/v1"

def call_openrouter_chat(messages, model="openai/gpt-4o", extra_params=None):
    """
    messages: list of dicts like [{"role": "user", "content": "..."}]
    extra_params: dict of additional parameters (temperature, stream, etc.)
    Returns the assistant content.
    """
    url = f"{OPENROUTER_BASE}/chat/completions"
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        # optional headers for attribution
        # "HTTP-Referer": "...",
        # "X-Title": "MyApp"
    }
    payload = {
        "model": model,
        "messages": messages,
    }
    if extra_params:
        payload.update(extra_params)
    resp = requests.post(url, headers=headers, json=payload)
    resp.raise_for_status()
    data = resp.json()
    # Assuming standard choice/message structure
    return data["choices"][0]["message"]["content"]

def summarize_with_openrouter(activity):
    prompt = f"""
    You are summarizing the contributions by a user in a PR.
    Summarize (in bullet points) the main features, refactors, bugfixes, tests, docs, and review comments from the following:

    Commit messages:
    { [c.commit.message for c in activity["commits"]] }

    Diff excerpts:
    { [d["patch"][:500] for d in activity["diffs"]] }

    Comments:
    { [c.body for c in activity["comments"]] }

    Reviews:
    { [r.body for r in activity["reviews"]] }
    """
    messages = [
        {"role": "system", "content": "You are a helpful code summarizer."},
        {"role": "user", "content": prompt}
    ]
    return call_openrouter_chat(messages, model="openai/gpt-4o")

def collect_user_activity(pr, user):
    commits = [c for c in pr.get_commits() if c.author and c.author.login == user]
    comments = [c for c in pr.get_issue_comments() if c.user.login == user]
    reviews = [r for r in pr.get_reviews() if r.user.login == user]
    diffs = []
    for commit in commits:
        for f in commit.files:
            if f.patch:
                diffs.append({"filename": f.filename, "patch": f.patch})
    return {
        "pr": pr,
        "commits": commits,
        "comments": comments,
        "reviews": reviews,
        "diffs": diffs
    }

def fetch_prs(repo_fullname, user):
    gh = Github(os.getenv("GITHUB_TOKEN"))
    repo = gh.get_repo(repo_fullname)
    pulls = repo.get_pulls(state="all")
    result = []
    for pr in pulls:
        # include PRs that user authored, or reviewed, or commented
        if pr.user.login == user:
            result.append(pr)
        else:
            # reviews or comments by user
            if any(r.user.login == user for r in pr.get_reviews()) or \
               any(c.user.login == user for c in pr.get_issue_comments()):
                result.append(pr)
    return result

def main(repo_fullname, target_user):
    prs = fetch_prs(repo_fullname, target_user)
    for pr in prs:
        act = collect_user_activity(pr, target_user)
        summary = summarize_with_openrouter(act)
        print(f"### PR #{pr.number}: {pr.title}\n{summary}\n\n")

if __name__ == "__main__":
    import sys
    repo = sys.argv[1]  # e.g. "owner/repo"
    user = sys.argv[2]
    main(repo, user)

