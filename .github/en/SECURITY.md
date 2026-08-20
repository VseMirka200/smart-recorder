# Security Policy

> **Русский:** [Открыть русскую версию](../SECURITY.md).

## Supported version

Security fixes are primarily applied to the current state of the `main` branch. Older local copies and independently modified builds may not receive fixes.

## What counts as a security issue

Examples include:

- unintended command execution;
- unsafe handling of recording files;
- capturing or exposing sensitive data without a clear user action;
- problems with downloaded dependencies or the local build process;
- screenshots, logs, or recordings unexpectedly exposing user data.

## Reporting

Do not publish passwords, tokens, personal data, private recordings, confidential screenshots, or detailed exploitation instructions for a critical vulnerability in a public Issue.

If GitHub Security Advisories or Private Vulnerability Reporting is enabled for the repository, use it. Otherwise, contact the repository owner through GitHub and share only the minimum information required to establish a private communication channel.

A useful report includes:

- affected version or commit SHA;
- problem description;
- reproduction steps;
- possible impact;
- a safe example or minimal test case;
- a proposed fix when known.

## Local data

Smart Recorder may work with user recordings and screenshots. Review such files before adding them to Issues or Pull Requests.

Runtime folders and common user artifacts are excluded through `.gitignore`, but contributors are still responsible for checking anything they publish.
