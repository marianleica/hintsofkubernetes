# Technical Mentee Onboarding Guide - Phase 1

## 1. Create a GitHub Public Repository

1. Go to [GitHub](https://github.com/) and sign in or create an account.
2. On your Dashboard page, click the **New** button (left pane) to create a new repository.
3. Enter a repository name and description, e.g. msactflows
4. Set the repository visibility to **Public**.
5. Click **Create repository**.
6. Install [GIT](https://git-scm.com/downloads) on your machine

## 2. Clone the Repository Locally

Open a terminal, go to the desired path in which to have the repo (e.g. C:\dev\) and run:

```bash
git clone https://github.com/<your-github-username>/<your-repo>.git
cd <your-repo>
```

## 3. Make Changes and Commit

- Add or modify files as needed.
- Stage your changes:

  ```bash
  git add .
  ```

- Commit your changes with a message:

  ```bash
  git commit -m "Describe your changes"
  ```

## 4. Push Changes to GitHub

> **ℹ️ Info:**  
> By default, your main branch is called `main`. If your branch is named differently, replace `main` with your branch name.

```bash
git push origin main
```

*(Replace `main` with your branch name, if different, by default it will be `main`.)*

> **ℹ️ Info:**  
> You will be using your editor (VSCode) to add your technical action plans and general information.
> The git steps to add, commit, and push will be used often after you made changes.
> Once pushed, the changes will reflect in your repository.  

## 5. Additional Tips

- Commit often with clear messages.
- Use branches for new features or experiments.
- Share your repository link with your mentor for feedback.

# Happy Coding!
