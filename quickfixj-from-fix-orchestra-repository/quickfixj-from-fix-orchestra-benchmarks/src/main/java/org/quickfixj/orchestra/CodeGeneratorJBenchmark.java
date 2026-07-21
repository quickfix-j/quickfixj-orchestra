/*
 * Copyright 2017-2024 FIX Protocol Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */
package org.quickfixj.orchestra;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.nio.file.Files;
import java.util.concurrent.TimeUnit;
import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Level;
import org.openjdk.jmh.annotations.Measurement;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.annotations.TearDown;
import org.openjdk.jmh.annotations.Warmup;

/**
 * JMH benchmarks for {@link CodeGeneratorJ}.
 *
 * <p>These benchmarks measure the end-to-end cost of generating QuickFIX/J Java source files from
 * a FIX Orchestra repository file. PR #68 introduced two optimisations relevant to this generator:
 * <ul>
 *   <li>Buffered file I/O (wrapping every {@code FileWriter} in a {@code BufferedWriter})</li>
 *   <li>A cached, static {@code JAXBContext} (avoids a classpath-scan on every call)</li>
 * </ul>
 *
 * <h2>Running the benchmarks</h2>
 * <pre>{@code
 * # Build the self-contained uber-jar
 * mvn -pl quickfixj-from-fix-orchestra-repository/quickfixj-from-fix-orchestra-benchmarks \
 *     -am package -DskipTests
 *
 * # Run all benchmarks
 * java -jar quickfixj-from-fix-orchestra-repository/quickfixj-from-fix-orchestra-benchmarks/target/benchmarks.jar
 *
 * # Run only this benchmark class
 * java -jar .../benchmarks.jar CodeGeneratorJBenchmark
 *
 * # Quick smoke-run (1 warm-up + 1 measurement iteration, 1 fork)
 * java -jar .../benchmarks.jar -wi 1 -i 1 -f 1 CodeGeneratorJBenchmark
 * }</pre>
 */
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.MILLISECONDS)
@State(Scope.Thread)
@Warmup(iterations = 3, time = 3, timeUnit = TimeUnit.SECONDS)
@Measurement(iterations = 5, time = 3, timeUnit = TimeUnit.SECONDS)
@Fork(value = 1, jvmArgsAppend = {"-Xms256m", "-Xmx256m"})
public class CodeGeneratorJBenchmark {

    /** URL of the FIX Orchestra repository file used as input. */
    private URL resourceUrl;

    /** Fresh output directory created before each benchmark iteration. */
    private File outputDir;

    @Setup(Level.Trial)
    public void setupTrial() {
        resourceUrl = CodeGeneratorJBenchmark.class
                .getClassLoader()
                .getResource("trade.xml");
        if (resourceUrl == null) {
            throw new IllegalStateException("trade.xml not found on the classpath");
        }
    }

    @Setup(Level.Iteration)
    public void setupIteration() throws IOException {
        outputDir = Files.createTempDirectory("benchmark-cg-").toFile();
    }

    @TearDown(Level.Iteration)
    public void tearDownIteration() {
        deleteRecursively(outputDir);
    }

    /**
     * Benchmark: full Java-class generation pipeline — unmarshal the Orchestra XML then write all
     * message/field/group/component Java source files.
     *
     * <p>Before PR #68 every call paid the cost of {@code JAXBContext.newInstance()} and every
     * generated file incurred un-buffered kernel write calls. After PR #68 the context is a shared
     * static field and all writes go through a {@code BufferedWriter}.
     */
    @Benchmark
    public void generateJavaClasses() throws Exception {
        CodeGeneratorJ generator = new CodeGeneratorJ();
        generator.generate(resourceUrl.openStream(), outputDir);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static void deleteRecursively(File dir) {
        if (dir == null || !dir.exists()) {
            return;
        }
        File[] children = dir.listFiles();
        if (children != null) {
            for (File child : children) {
                deleteRecursively(child);
            }
        }
        dir.delete();
    }
}
