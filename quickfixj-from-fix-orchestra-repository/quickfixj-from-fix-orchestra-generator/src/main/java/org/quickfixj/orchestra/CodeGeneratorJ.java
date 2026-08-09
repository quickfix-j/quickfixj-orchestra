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
 *
 */
package org.quickfixj.orchestra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import javax.xml.transform.TransformerException;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.HashMap;
import java.util.Map;

/**
 * Generates message classes for QuickFIX/J from a FIX Orchestra file.
 * <p>
 * This implementation delegates all generation work to XSLT 2.0 stylesheets executed via
 * {@link OrchestraTransformer} with the Saxon processor. The CLI and Maven-plugin entry points
 * are unchanged.
 */
public class CodeGeneratorJ {

	private static final Logger logger = LoggerFactory.getLogger(CodeGeneratorJ.class);

	static final int SPACES_PER_LEVEL = 2;

	private static final int FAIL_STATUS = 1;

	private boolean isGenerateBigDecimal = true;
	private boolean isGenerateOnlySession = false;
	private boolean isExcludeSession = false;
	private boolean isGenerateFixt11Package = true;

	/**
	 * Runs a CodeGeneratorJ with command line arguments.
	 *
	 * @param args command line arguments.
	 */
	public static void main(String[] args) {
		final CodeGeneratorJ generator = new CodeGeneratorJ();
		Options options = new Options();
		new CommandLine(options).execute(args);
		try (FileInputStream inputStream = new FileInputStream(new File(options.orchestraFileName))) {
			generator.setGenerateBigDecimal(!options.isDisableBigDecimal);
			generator.setGenerateOnlySession(options.isGenerateOnlySession);
			if (generator.isExcludeSession && generator.isGenerateFixt11Package) {
				logger.error("Options {} == {} and {} == {} are mutually exclusive.",
						Options.EXCLUDE_SESSION, options.isExcludeSession,
								Options.GENERATE_FIXT11_PACKAGE, options.isGenerateFixt11Package);
				System.exit(FAIL_STATUS);
			}
			generator.setExcludeSession(options.isExcludeSession);
			generator.setGenerateFixt11Package(options.isGenerateFixt11Package);
            generator.generate(inputStream, new File(options.outputDir));
		} catch (Exception e) {
			logger.error("Code generation failed", e);
		}
	}

	@Command(name = "Options", mixinStandardHelpOptions = true, description = "Options for generation of QuickFIX/J Code from a FIX Orchestra Repository")
	static class Options {
		static final String GENERATE_FIXT11_PACKAGE = "--generateFixt11Package";
		static final String EXCLUDE_SESSION = "--excludeSession";

		@Option(names = { "-o", "--output-dir" }, defaultValue = "target/generated-sources",
				paramLabel = "OUTPUT_DIRECTORY", description = "The output directory, Default : ${DEFAULT-VALUE}")
		String outputDir = "target/generated-sources";

		@Option(names = { "-i", "--orchestra-file" }, required = true,
				paramLabel = "ORCHESTRA_FILE", description = "The path/name of the FIX OrchestraFile")
		String orchestraFileName;

		@Option(names = { "--disableBigDecimal" }, defaultValue = "false", fallbackValue = "true",
				paramLabel = "DISABLE_BIG_DECIMAL", description = "Disable the use of Big Decimal for Decimal Fields, Default : ${DEFAULT-VALUE}")
		boolean isDisableBigDecimal = true;

		@Option(names = { "--generateOnlySession" }, defaultValue = "false", fallbackValue = "true",
				paramLabel = "GENERATE_ONLY_SESSION", description ="Generates Only Session Classes and dependencies : ${DEFAULT-VALUE}")
		boolean isGenerateOnlySession = false;

		@Option(names = { EXCLUDE_SESSION }, defaultValue = "false", fallbackValue = "true",
				paramLabel = "EXCLUDE_SESSION", description ="Excludes Session Category Messages, Components and Groups exclusive to Session Layer and Fields used by Session Layer from the generated code, Default : ${DEFAULT-VALUE}")
		boolean isExcludeSession = false;

		@Option(names = { GENERATE_FIXT11_PACKAGE }, defaultValue = "true", fallbackValue = "true",
				paramLabel = "GENERATE_FIXT_PACKAGE", description ="Generates FIXT11 Package : ${DEFAULT-VALUE}")
		boolean isGenerateFixt11Package = true;
	}

	/**
	 * Generates QuickFIX/J Java source files from the supplied Orchestra XML stream.
	 *
	 * @param inputFile  Orchestra XML input stream
	 * @param outputDir  base directory for generated Java sources
	 * @throws IOException if writing the temp file or reading the input fails
	 */
	public void generate(InputStream inputFile, File outputDir) throws IOException, TransformerException {
		// Copy the stream to a temp file so Saxon can parse it twice (fields + messages).
		File tempInput = File.createTempFile("orchestra-input-", ".xml");
		try {
			Files.copy(inputFile, tempInput.toPath(), StandardCopyOption.REPLACE_EXISTING);

			Map<String, String> params = buildParams();
			OrchestraTransformer transformer = new OrchestraTransformer();
			transformer.transform(tempInput, "xslt/code-generator-fields.xsl", outputDir, params);
			transformer.transform(tempInput, "xslt/code-generator-messages.xsl", outputDir, params);
		} finally {
			tempInput.delete();
		}
	}

	private Map<String, String> buildParams() {
		Map<String, String> params = new HashMap<>();
		params.put("generateBigDecimal", Boolean.toString(isGenerateBigDecimal));
		params.put("generateFixt11Package", Boolean.toString(isGenerateFixt11Package));
		params.put("excludeSession", Boolean.toString(isExcludeSession));
		params.put("generateOnlySession", Boolean.toString(isGenerateOnlySession));
		return params;
	}

	public void setGenerateBigDecimal(boolean isGenerateBigDecimal) {
		this.isGenerateBigDecimal = isGenerateBigDecimal;
	}

	public boolean isExcludeSession() {
		return isExcludeSession;
	}

	public void setExcludeSession(boolean isExcludeSession) {
		if (isExcludeSession && this.isGenerateFixt11Package) {
			throw new IllegalArgumentException("ExcludeSession == true and GenerateFixt11Package == true are mutually exclusive.");
		}
		if (isExcludeSession && this.isGenerateOnlySession) {
			throw new IllegalArgumentException("ExcludeSession == true and GenerateSessionOnly == true are mutually exclusive.");
		}
		this.isExcludeSession = isExcludeSession;
	}

	public boolean isGenerateFixt11Package() {
		return isGenerateFixt11Package;
	}

	public void setGenerateFixt11Package(boolean isGenerateFixt11Package) {
		if (isGenerateFixt11Package && this.isExcludeSession) {
			throw new IllegalArgumentException("GenerateFixt11Package == true and ExcludeSession = true are mutually exclusive.");
		}
		this.isGenerateFixt11Package = isGenerateFixt11Package;
	}

	public boolean isGenerateOnlySession() {
		return isGenerateOnlySession;
	}

	public void setGenerateOnlySession(boolean isGenerateSessionOnly) {
		if (isGenerateSessionOnly && this.isExcludeSession) {
			throw new IllegalArgumentException("GenerateSessionOnly == true and ExcludeSession = true are mutually exclusive.");
		}
		this.isGenerateOnlySession = isGenerateSessionOnly;
	}
}
