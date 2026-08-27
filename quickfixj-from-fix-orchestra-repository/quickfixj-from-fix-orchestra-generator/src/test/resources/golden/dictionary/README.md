# Golden Files for Orchestra Data Dictionary Generator Regression Tests

This directory contains the reference ("golden") output of `DataDictionaryGenerator` for
**FIXLatest**. They are used by `DataDictionaryGoldenFileTest` to catch unintended changes
to generated data-dictionary XML files.

## Directory layout

```
golden/
  dictionary/   – output generated from OrchestraFIXLatest.xml
    FIXLatest.xml
```

The test fixture `OrchestraFIXLatest.xml` (in `src/test/resources/`) is the full
`OrchestraFIXLatest.xml` taken from the `io.fixprotocol.orchestrations:fix-standard`
artifact at the version declared in the parent POM.

## What the test does

`DataDictionaryGoldenFileTest` runs `DataDictionaryGenerator` against the fixture into a
temporary folder, then walks every `.xml` file and asserts line-by-line equality with the
corresponding file here.  Missing or extra files also fail the test.

## When the generator output changes intentionally

1. Make your generator changes.
2. Run `DataDictionaryGenerator` (or let the test write to a known path temporarily) to
   produce the new output:
   ```bash
   ./mvnw test -pl quickfixj-from-fix-orchestra-repository/quickfixj-from-fix-orchestra-generator \
       -Dtest=DataDictionaryGeneratorTest#testGenerateFIXLatest -DfailIfNoTests=false
   # copy target/spec/FIXLatest.xml here
   cp quickfixj-from-fix-orchestra-repository/quickfixj-from-fix-orchestra-generator/target/spec/FIXLatest.xml \
      quickfixj-from-fix-orchestra-repository/quickfixj-from-fix-orchestra-generator/src/test/resources/golden/dictionary/FIXLatest.xml
   ```
3. Verify only the expected files changed:
   ```bash
   git diff --stat quickfixj-from-fix-orchestra-repository/quickfixj-from-fix-orchestra-generator/src/test/resources/golden/dictionary/
   ```
4. Run the test suite to confirm the updated golden files now match:
   ```bash
   ./mvnw test -pl quickfixj-from-fix-orchestra-repository/quickfixj-from-fix-orchestra-generator \
       -Dtest=DataDictionaryGoldenFileTest
   ```
5. Commit the updated golden files **together with your generator changes** in the same
   commit (or PR) so reviewers can see the diff side-by-side.
