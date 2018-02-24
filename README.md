# GitHub Labels Copy

<div style="text-align:center">
<img src="assets/bouncercat.png" width="25%" />
</div>

Typically, a [GitHub](https://github.com/) account consists of several sub-projects. To make the labels consistent, we can use some tool to copy the label from a source project to a destination project. The purpose of this repository is to help doing this job more easily, with less effort. This repository is using the [`copy-github-labels`](https://github.com/jvandemo/copy-github-labels) as dependency. To organize the scrum workflow follow [this](https://github.com/jvandemo/github-scrum-workflow) work.

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

3. Go to [`index.js`](https://github.com/FMCalisto/github-labels-copy/blob/master/src/index.js) file;

4. Edit the [`source`](https://github.com/FMCalisto/github-labels-copy/blob/master/src/index.js#L13) information;

5. Edit the [`destination`](https://github.com/FMCalisto/github-labels-copy/blob/master/src/index.js#L17) information;

6. [Edit the token](https://github.com/FMCalisto/github-labels-copy/blob/master/src/index.js#L25) you created on phase number (2.) of this section;

## Run

1. Go to the folder root:

```
cd github-labels-copy
```

2. Run the project by doing:

```
npm start
```
