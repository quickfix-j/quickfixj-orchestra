package org.quickfixj.orchestra;

import static org.junit.jupiter.api.Assertions.assertEquals;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import io.fixprotocol._2020.orchestra.repository.Repository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import javax.xml.bind.JAXBContext;
import javax.xml.bind.Unmarshaller;

public class DataDictionaryGeneratorTest {

  private DataDictionaryGenerator generator;

  @BeforeEach
  public void setUp() throws Exception {
    generator = new DataDictionaryGenerator();
  }

  @Test
  public void testGenerateFIX50SP2() throws Exception {
    File outputDir = new File("target/spec");
    generator.generate(
        Thread.currentThread().getContextClassLoader().getResource("trade.xml").openStream(),
        outputDir);
    try (BufferedReader brTest = new BufferedReader(
        new FileReader(outputDir.getAbsolutePath().concat(File.separator + "FIX50SP2.xml")))) {
      String firstLine = brTest.readLine();
      assertEquals("<fix major=\"5\" minor=\"0\" servicepack=\"2\" extensionpack=\"257\">",
          firstLine);
    }
  }
  
  @Test
  public void testGenerateFIXLatest() throws Exception {
    File outputDir = new File("target/spec");
    generator.generate(
        Thread.currentThread().getContextClassLoader().getResource("trade-latest.xml").openStream(),
        outputDir);
    try (BufferedReader brTest = new BufferedReader(
        new FileReader(outputDir.getAbsolutePath().concat(File.separator + "FIXLatest.xml")))) {
      String firstLine = brTest.readLine();
      assertEquals("<fix major=\"Latest\" minor=\"0\" servicepack=\"0\" extensionpack=\"269\">",
          firstLine);
    }
  }

  @Test
  public void testGenerateFIXLatestFromRepository(@TempDir Path tempDir) throws Exception {
    JAXBContext jaxbContext = JAXBContext.newInstance(Repository.class);
    Unmarshaller unmarshaller = jaxbContext.createUnmarshaller();
    Repository repository;

    try (InputStream stream = Thread.currentThread().getContextClassLoader().getResource("trade-latest.xml").openStream()) {
      repository = (Repository) unmarshaller.unmarshal(stream);
    }

    Path outputDir = tempDir.resolve("output");
    Files.createDirectory(outputDir);

    generator.generate(repository, outputDir.toFile());
    try (BufferedReader brTest = Files.newBufferedReader(outputDir.resolve("FIXLatest.xml"))) {
      String firstLine = brTest.readLine();
      assertEquals("<fix major=\"Latest\" minor=\"0\" servicepack=\"0\" extensionpack=\"269\">",
          firstLine);
    }
  }

  @Test
  public void testExtract() throws Exception {
    assertEquals("0", generator.extractServicePack("FIX.5.0"));
    assertEquals("2", generator.extractServicePack("FIX.5.0SP2"));
    assertEquals("2", generator.extractServicePack("FIX.5.0SP2_EP257"));
    assertEquals("0", generator.extractServicePack("FIX.Latest_EP269"));
    
    assertEquals("257", generator.extractExtensionPack("FIX.5.0SP2_EP257"));
    assertEquals("0", generator.extractExtensionPack("FIX.5.0"));
    assertEquals("0", generator.extractExtensionPack("FIX.5.0SP2"));
    assertEquals("123", generator.extractExtensionPack("FIX.5.0_EP123"));
    assertEquals("269", generator.extractExtensionPack("FIX.Latest_EP269"));
    
    assertEquals("FIX.5.0", generator.splitOffVersion("FIX.5.0"));
    assertEquals("FIX.5.0", generator.splitOffVersion("FIX.5.0_EP123"));
    assertEquals("FIX.5.0SP2", generator.splitOffVersion("FIX.5.0SP2"));
    assertEquals("FIX.5.0SP2", generator.splitOffVersion("FIX.5.0SP2_EP257"));
    assertEquals("FIX.Latest", generator.splitOffVersion("FIX.Latest_EP269"));
  }
  
  @Test
  public void testRegExp1() throws Exception {
      final String version = "FIX.5.0SP2_EP257";
      final String regex = "(FIX\\.)(?<major>\\d+)(\\.)(?<minor>\\d+)(.*)";
      final Pattern pattern = Pattern.compile(regex);
      final Matcher matcher = pattern.matcher(version);
      if (matcher.find()) {
        String extensionPack = generator.extractExtensionPack(version);
        String servicePack = generator.extractServicePack(version);
        int major = Integer.parseInt(matcher.group("major"));
        int minor = Integer.parseInt(matcher.group("minor"));
        assertEquals(major, 5);
        assertEquals(minor, 0);
      }
   }

}
