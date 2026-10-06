# Contributing to Dozer

There are various ways to contribute to Dozer, and all are welcome and appreciated!

- [Bug reports](#bug-reports)
- [Feature requests](#feature-requests)
- [Design](#design)
- [Code](#code)
    - [Getting started](#getting-started)
    - [Submitting your pull request](#submitting-your-pull-request)

## Bug reports
Open issues about problems you may be encountering. When doing so please mention the version you're using.

## Feature requests
If you have a good idea for a feature or enhancement open an issue.

## Design
Refresh the Dozer icons or logo. [Design resources for logo and status bar icon](https://www.figma.com/file/g5MhiwxR1YFg5vti0tPANa/Dozer).

## Code
You can submit your own code. This can be bug fixes or new features. For bigger features, open an issue first to discuss them. Check out [Issues](https://github.com/pawiromitchel/Dozer/issues).

### Getting started
You need the Xcode Command Line Tools (`xcode-select --install`). Xcode itself is optional.

```shell
git clone https://github.com/pawiromitchel/Dozer &&
cd Dozer &&
make run
```

`make test` runs the unit tests. Opening the folder in Xcode works too, because Dozer is a plain Swift package.

### Submitting your pull request
Please give a small summary of what has changed. Also add any github issues links (`Fixes #100`).
Once your pull request is created, please add a changelog entry to the CHANGELOG.md along with the PR number.