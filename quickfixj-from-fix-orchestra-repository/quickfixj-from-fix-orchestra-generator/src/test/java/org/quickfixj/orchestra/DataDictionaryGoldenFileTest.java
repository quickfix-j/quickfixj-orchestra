package org.quickfixj.orchestra;

import static org.junit.jupiter.api.Assertions.fail;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Golden-file regression test for the orchestra-based data dictionary generator.
 *
 * <p>The test runs {@link DataDictionaryGenerator} against the committed
 * {@code OrchestraFIXLatest.xml} test fixture and compares every generated
 * {@code .xml} file byte-for-byte against the committed golden files stored in
 * {@code src/test/resources/golden/dictionary}.
 *
 * <p>If the generator output must intentionally change, regenerate the golden files by
 * running the data dictionary generator directly against the same XML fixture and committing
 * the updated golden files together with the generator changes. See
 * {@code src/test/resources/golden/dictionary/README.md} for the golden-file workflow.
 */
public class DataDictionaryGoldenFileTest {

    private DataDictionaryGenerator generator;

    @BeforeEach
    public void setUp() {
        generator = new DataDictionaryGenerator();
    }

    @Test
    public void testFIXLatestGenerationMatchesGolden(@TempDir Path tempDir) throws Exception {
        URL goldenDirUrl = DataDictionaryGoldenFileTest.class.getResource("/golden/dictionary");
        if (goldenDirUrl == null) {
            fail("Golden directory /golden/dictionary not found on classpath – "
                    + "add the golden files under src/test/resources/golden/dictionary/");
        }
        File goldenDir = new File(goldenDirUrl.toURI());

        Path outputDir = tempDir.resolve("dictionary");
        Files.createDirectory(outputDir);

        try (InputStream orchestraXml = DataDictionaryGoldenFileTest.class
                .getResourceAsStream("/OrchestraFIXLatest.xml")) {
            if (orchestraXml == null) {
                fail("Test resource OrchestraFIXLatest.xml not found on classpath");
            }
            generator.generate(orchestraXml, outputDir.toFile());
        }

        assertMatchesGolden(goldenDir, outputDir.toFile(), "DataDictionary/FIXLatest");
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private void assertMatchesGolden(File golden, File generated, String label)
            throws IOException {
        List<String> errors = new ArrayList<>();

        List<String> goldenPaths    = collectXmlPaths(golden.toPath());
        List<String> generatedPaths = collectXmlPaths(generated.toPath());

        List<String> missing = new ArrayList<>(goldenPaths);
        missing.removeAll(generatedPaths);
        for (String p : missing) {
            errors.add("[" + label + "] Missing generated file: " + p);
        }

        List<String> extra = new ArrayList<>(generatedPaths);
        extra.removeAll(goldenPaths);
        for (String p : extra) {
            errors.add("[" + label + "] Unexpected generated file (not in golden): " + p);
        }

        for (String relPath : goldenPaths) {
            if (!generatedPaths.contains(relPath)) {
                continue;
            }
            compareFileContent(
                    new File(golden,    relPath),
                    new File(generated, relPath),
                    relPath, label, errors);
        }

        if (!errors.isEmpty()) {
            fail(errors.size() + " golden file assertion(s) failed:\n"
                    + String.join("\n", errors));
        }
    }

    private List<String> collectXmlPaths(Path root) throws IOException {
        if (!root.toFile().exists()) {
            return new ArrayList<>();
        }
        try (Stream<Path> stream = Files.walk(root)) {
            return stream
                    .filter(p -> p.toString().endsWith(".xml"))
                    .map(p -> root.relativize(p).toString())
                    .sorted()
                    .collect(Collectors.toList());
        }
    }

    private void compareFileContent(File goldenFile, File generatedFile, String relPath,
            String label, List<String> errors) throws IOException {
        List<String> goldenLines    = Files.readAllLines(goldenFile.toPath());
        List<String> generatedLines = Files.readAllLines(generatedFile.toPath());

        int maxLines = Math.max(goldenLines.size(), generatedLines.size());
        for (int i = 0; i < maxLines; i++) {
            String gLine = i < goldenLines.size()    ? goldenLines.get(i)    : "<EOF>";
            String aLine = i < generatedLines.size() ? generatedLines.get(i) : "<EOF>";
            if (!gLine.equals(aLine)) {
                errors.add(String.format(
                        "[%s] %s line %d differs:%n  golden:    %s%n  generated: %s",
                        label, relPath, i + 1, gLine, aLine));
                break; // report only first differing line per file
            }
        }
        if (goldenLines.size() != generatedLines.size() && errors.isEmpty()) {
            errors.add(String.format(
                    "[%s] %s line count differs: golden=%d, generated=%d",
                    label, relPath, goldenLines.size(), generatedLines.size()));
        }
    }
}
