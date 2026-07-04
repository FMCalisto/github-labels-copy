# GitHub Labels Copy

<p align="center">
<img src="assets/bouncercat.png" width="50%" />
</p>

Typically, a [GitHub](https://github.com/) account consists of several sub-projects. To make the labels consistent, we can use some tool to copy the label from a source project to a destination project. The purpose of this repository is to help doing this job more easily, with less effort. This repository is based on the [`copy-github-labels`](https://github.com/jvandemo/copy-github-labels) repository. To organize the workflow follow [this](https://github.com/jvandemo/github-scrum-workflow) work.

## Clone & Install

1. Clone the repository:

```
git clone git@github.com:FMCalisto/github-labels-copy.git
```

2. Get inside the root:

```
cd github-labels-copy
```

3. Install dependencies:

```
npm install
```

## Instructions

1. Go to [Settings](https://github.com/settings/tokens)

2. [Generate a new token](https://github.com/settings/tokens/new) for personal access token;

3. Copy [`src/sample-config.json`](https://github.com/FMCalisto/github-labels-copy/blob/master/src/sample-config.json) to `src/config.json`;

4. Edit `src/config.json` with your GitHub token and repository details:

```json
{
  "githubToken": "<your-personal-access-token>",
  "sourceOwner": "<source-owner>",
  "sourceRepo": "<source-repo>",
  "targetRepos": [
    {
      "owner": "<target-owner-1>",
      "repo": "<target-repo-1>"
    },
    {
      "owner": "<target-owner-2>",
      "repo": "<target-repo-2>"
    }
  ]
}
```

> **Bulk Operations:** You can list as many repositories as needed in `targetRepos` to copy labels from the source to multiple repositories in a single run.

> **Backward Compatibility:** The legacy single-target fields `targetOwner` and `targetRepo` are still supported. If `targetRepos` is not present, the tool falls back to `targetOwner`/`targetRepo`.

## Run

1. Go to the folder root:

```
cd github-labels-copy
```

2. Run the project by doing:

```
npm start
```
