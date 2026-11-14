# Repository to QuickFIX/J Code Generation Maven Plugin

![](../../FIXorchestraLogo.png)

This module provides the Maven Plugin to generate QuickFIX/J code for Messages and Fields given a FIX Orchestra repository file.

The `excludeDeprecated` parameter optionally excludes deprecated fields, messages,
code sets, and values. It defaults to `false`, so deprecated artifacts are
generated unless filtering is explicitly requested.
