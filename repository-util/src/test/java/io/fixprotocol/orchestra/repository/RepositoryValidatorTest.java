package io.fixprotocol.orchestra.repository;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;


public class RepositoryValidatorTest {
  
  RepositoryValidatorImpl validator;
  
  @BeforeAll
  public static void setupOnce() {
    new File(("target/test")).mkdirs();
  }

  @BeforeEach
  public void setUp() throws Exception {
    validator = new RepositoryValidatorImpl();
  }

  @Test
  public void testValidateWithErrors() throws FileNotFoundException {
    InputStream inputStream = new FileInputStream("src/test/resources/repositorywitherrors.xml");
    OutputStream jsonOutputStream = new FileOutputStream("target/test/repositorywitherrors.json");
    validator.validate(inputStream, jsonOutputStream, false);
  }
  
  @Test
  public void testValidate() throws FileNotFoundException {
    InputStream inputStream = new FileInputStream("src/test/resources/OrchestraFIXLatest.xml");
    OutputStream jsonOutputStream = new FileOutputStream("target/test/OrchestraFIXLatest.json");
    validator.validate(inputStream, jsonOutputStream, false);
  }

}