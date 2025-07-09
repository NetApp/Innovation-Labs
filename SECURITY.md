Thanks for helping make safer software for everyone.

# Security

NetApp takes the security of our software products and services seriously, including all of
the open source code repositories managed through our GitHub organizations, such as [NetApp](https://github.com/NetApp).

# Reporting Potential Security Issues
If you believe you have found a potential security vulnerability in any NetApp-owned repository,
please report it to us through coordinated disclosure. 

**Please do not report security vulnerability through public GitHub issues, discussions, or pull requests** 

Instead, please send an email to **ng-innovation-labs-git[@]netapp.com**. 

Please include as much of the infomration listed below as you can to help us better understand and resolve the issue:
- Type of security vulnerability (e.g. buffer overflow, injection, cross-site scripting, ...)
- Full paths of source file(s) related to the issue
- The location of the affected source code (tag, branch, commit or direct URL)
- A step-by-step description indicating how to reproduce the issue
- Proof-of-Concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit the issue

This informaiton will help us triage your report more quickly. 

## Policy

If we verify a reported security vulnerability, our policy is:
- We will patch the current release branch, as well as the immediate prior minor
  release branch.
- After patching the release branches, we will immediately issue new security
  fix releases for each patched release branch.
- A security advisory will be released on the project GitHub repository detailing the
  vulnerability, as well as recommendations for end-users to protect themselves.
