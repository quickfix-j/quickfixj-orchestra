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

import javax.xml.transform.TransformerException;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

/**
 * Generates a QuickFIX data dictionary from a FIX Orchestra file.
 * <p>
 * This format is consumable by the C++, Java and .NET versions of QuickFIX.
 * <p>
 * This implementation delegates generation work to the {@code data-dictionary.xsl} XSLT 2.0
 * stylesheet executed via {@link OrchestraTransformer}.
 *
 * @author Don Mendelson
 */
public class DataDictionaryGenerator {

  /**
   * Runs a DataDictionaryGenerator with command line arguments.
   *
   * @param args command line arguments. The first argument is the name of a FIX Orchestra file. An
   *        optional second argument is the target directory for generated files. It defaults to
   *        directory "spec".
   */
  public static void main(String[] args) {
    final DataDictionaryGenerator generator = new DataDictionaryGenerator();
    if (args.length >= 1) {
      final File inputFile = new File(args[0]);
      File outputDir;
      if (args.length >= 2) {
        outputDir = new File(args[1]);
      } else {
        outputDir = new File("spec");
      }
      try (FileInputStream inputStream = new FileInputStream(inputFile)) {
        generator.generate(inputStream, outputDir);
      } catch (Exception e) {
        e.printStackTrace(System.err);
      }
    } else {
      new DataDictionaryGenerator().usage();
    }
  }

  /**
   * Generates QuickFIX data dictionaries from the supplied Orchestra XML stream.
   *
   * @param inputFile  Orchestra XML input stream
   * @param outputDir  directory in which to write the generated {@code .xml} files
   * @throws IOException          if I/O fails
   * @throws TransformerException if XSLT transformation fails
   */
  public void generate(InputStream inputFile, File outputDir)
      throws IOException, TransformerException {
    File tempInput = File.createTempFile("orchestra-dict-input-", ".xml");
    try {
      Files.copy(inputFile, tempInput.toPath(), StandardCopyOption.REPLACE_EXISTING);
      outputDir.mkdirs();
      new OrchestraTransformer().transform(tempInput, "xslt/data-dictionary.xsl", outputDir, null);
    } finally {
      tempInput.delete();
    }
  }

  // -------------------------------------------------------------------------
  // Helper methods kept for unit tests
  // -------------------------------------------------------------------------

  String splitOffVersion(String version) {
    String[] parts = version.split("_");
    if (parts.length > 0) {
      version = parts[0];
    }
    return version;
  }

  String extractExtensionPack(String version) {
    String extensionPack = "0";
    String[] parts = version.split("_EP");
    if (parts.length > 1) {
      extensionPack = parts[1];
    }
    return extensionPack;
  }

  String extractServicePack(String version) {
    String servicePack = "0";
    String[] parts = version.split("SP");
    if (parts.length > 1) {
      servicePack = parts[1];
    }
    parts = servicePack.split("_");
    if (parts.length > 1) {
      servicePack = parts[0];
    }
    return servicePack;
  }

  private void usage() {
    System.out.format("Usage: java %s <input-file> <output-dir>", this.getClass().getName());
  }
}
