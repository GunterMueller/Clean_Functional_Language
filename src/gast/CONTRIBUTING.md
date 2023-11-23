# Contributing to Gast

Thank you for contributing to the Gast.
This document describes how we work here.

[[_TOC_]]

## General workflow

- Bugs and feature proposals are tracked in the issue tracker.
- We use feature branches to fix bugs, develop new features, etc. Feature
  branch names should be descriptive.
- Once code is ready to be merged into master this is done in a merge request.
- Merge requests are assigned to the person who currently has to work on it.
  This can be a reviewer when the code is ready for review, or somebody else,
  if more work is required before the MR can be merged. Merge requests that are
  not ready for review should also be marked as Drafts.
- Comment threads are resolved by the person who started them, not the person
  who answers them. This makes sure that everyone has an overview of what
  remains to be done.

## Git

- We prefer `git rebase` over `git merge` to bring feature branches up to date
  with master, as this makes `git bisect` easier.
- Intermediate commits should compile to make `git bisect` easier. Use
  `git rebase -i` to squash commits and clean up your history before making a
  merge request.

## Code Review

- Code has to be reviewed and accepted by at least another person, who did not
  contribute a significant amount of code.
- The reviewer checks whether the changes are in accordance with this document
  and can also bring in other ideas improving the result. The review is
  repeated until the reviewer agrees that the item is done and can be merged.

The reviewer is not required to:

- Reproduce benchmark results if they seem plausible.
- Check if all intermediate commits compile.

### Code owners

Because not everybody is well-versed in all parts of the code base, merge
requests that make significant changes should be reviewed by a *code owner*. In
a continuous effort to improve all of our knowledge of the code base, it is
first reviewed by a *code owner trainee*, who then passes it on to a code owner
for final review and merge. This seems like a complicated process, but the final
step is supposed to be short.

The code owners are:
@smichels

To find out which code owner to assign, it is best to look at the git history.
When in doubt, it is best to assign the first person from the list above.

## Code Style

- The code has to be checked against the
  [Platform code style](https://gitlab.com/clean-and-itasks/clean-platform/-/blob/master/doc/STANDARDS.md).
- The style guide can only be extended once we have automated style checking;
  otherwise this takes too much review time.

## Efficiency

Premature optimisation lead to waste of time and can decrease maintainability
of code. There is on the other hand no reason to waste performance by not
following some good practices, requiring minimal effort and not affecting
maintainability. Not choosing the appropriate types beforehand can waste
performance and time when implementations have to be refactored afterwards.

The following points should always hold:

- All functions and types should have proper strictness annotations.
- Appropriate choices have been made for types (e.g. `Set` vs `[]`).
- The most efficient library functions available should be used (e.g. `+++` and
  `concat3`/`4`/`5` vs `concat`, lazy vs strict `foldl`).

If performance is part of the acceptance criteria of an issue, a benchmark
should be done to show that the desired performance is achieved.

## Testing

### Existing Tests

- Existing tests should be adapted if required so that the CI pipeline passes.

### New Tests

- For fixed bugs there should always be a test, which failed before the MR and
  passes after the MR. How thorough the test needs to be depends on the
  probability and impact of failure and can be determined in cooperation with
  the reviewer.
- In exceptional cases the writing of tests can be delayed to a follow-up
  issue, for example if writing the test is complex or impossible with the
  current framework and/or if the bug has very high priority.

## Documentation

- All changed/added exported functions and types should be correctly documented
  in the definition module according to the
  [Platform documentation standards](https://gitlab.com/clean-and-itasks/clean-platform/-/blob/master/doc/DOCUMENTATION.md).
- In implementation modules unusual choices (e.g. fancy optimisations) or parts
  which are likely to get broken in the future (e.g. arguments which have to
  remain lazy) should be documented.
- *What* code does should become clear from the code itself. Good structure and
  naming is important to achieve this. Comments should explain *why* certain
  non-straightforward choices have been made.
- Each commit should have a self-contained purpose with a clear commit message
  explaining the what and why of the change. Each commit should compile and
  preferably yield a testable system.

### Changelog

We maintain a changelog during development. The changelog forms the basis for
release notes. Our changelog workflow is based on
[that of GitLab](https://docs.gitlab.com/ee/development/changelog.html).

During development a changelog entry is a file `XXX.yml` in
[changelog](/changelog), where `XXX` is the merge request ID. It is a
[YAML](https://yaml.org/) file:

```yaml
type: fixed
title: Generate less duplicates in ggen{|Real|}; document this instance.
author: Camil Staps (@camilstaps)
```

- `type` is required and must be one of added, fixed, changed, deprecated,
  removed, security, performance, and other.
- `title` is required and must be capitalized and end with a period.
- `author` is optional and can contain full name and/or email address and/or
  GitLab username. It is recommended for people who do not contribute
  regularly.

These files are collected into the [changelog](/CHANGELOG.md) when
preparing a new release, e.g.:

```md
### Bug fixes
- Generate less duplicates in ggen{|Real|}; document this instance. Camil Staps (@camilstaps), !35
```

Use the following guidelines to determine whether a merge request should have a
changelog entry:

- An entry is *required* if behaviour is changed in a way that impacts
  application users (e.g., the default layout of buttons has changed).
- An entry is *required* if a public API is changed (e.g., the type of a
  combinator has changed).
- Changes contributed by irregular contributors *may* always have an entry if
  they desire (e.g., "Fixed a typo in README.md").
- Documentation-only changes *should not* have an entry.
- Bug fixes for regressions introduced within the same release cycle *should
  not* have an entry.
- Developer-facing changes (e.g., refactoring) *should not* have an entry.

## Planning

### Solving issues
We commit to solving issues and adding functionality at a steady pace. We only
work on issues that are in GitLab's issue list. This means that we will not
respond to feature requests and bug reports by any other means (e.g. e-mail).

All communication regarding an issue will also take place on GitLab; either in
the issue itself or in related MRs.

After an issue has been submitted, we will evaluate and prioritize it. We
strongly encourage you to use the various issue templates in GitLab when
submitting an issue, and to be verbose when describing the issue. This
prevents confusion and additional communication. We prioritize all new issues
at least once a week.

Once an issue has been prioritized, it receives a label. We use the following labels:

|Priority|Intention|
---|---
|gast~"TOP Priority::1"|We definitely want this. It's a major bug/feature that affects many users.|
|gast~"TOP Priority::2"|We want this, but it's not totally clear or extremely important.|
|gast~"TOP Priority::3"|We might want this, but it's not near-term roadmap material. We would review MRs, but are unlikely to work on it ourselves. If the MR is too complex, the issue may be closed without resolution or delayed.|
|gast~"TOP Priority::4"|We basically don't see any need for this. If somebody implements it we might look at it, but if it involves significant complexity, it will likely be rejected.|

(The labeling system is inspired by https://wiki.mozilla.org/Bugzilla:Priority_System.)

We are open to discussion on priorities with submitters or other stakeholders,
but at the same time we aim to streamline the prioritization process as much as
possible, so we can focus most of our time on solving actual issues.

### Reviewing contributions by others
Contributors can submit MRs at any time. Code owners for the respective sub-
systems will respond to these MRs within a week, either by reviewing (and
then merging or commenting), or otherwise by at least indicating when the review
will happen.

## Release schedule

We have the intention of moving towards a faster review schedule, but this is
currently blocked on infrastructure issues. Eventually we want to move to a
system like the following:

- A release every month or 4 weeks, which is synchronized with Platform, tagged
  by year and iteration (e.g. `21.4`).
- A two-week freeze on features and non-trivial fixes before each release.
- Fixes for serious issues can be backported, creating versions like `21.4.1`.

The details of this schedule are for discussion later.

### Release checklist
To make a release, do the following:
- Make a branch with the name of the release, e.g. `21-4`.
- In this branch, update CHANGELOG.md, using the various changelog fragments in separate `changelog/*.yml` files.
- Delete the `yml` changelog fragments.
- Commit the changes, using the commmit message `Release XXX`.
- Push the branch.
- Merge the branch.
- Create and push a tag on the `master` branch with the name of the release, e.g. `21.4`.
