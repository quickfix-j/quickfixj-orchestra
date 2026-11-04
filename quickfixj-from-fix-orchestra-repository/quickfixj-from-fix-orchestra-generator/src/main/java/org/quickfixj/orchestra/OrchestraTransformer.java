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

import net.sf.saxon.lib.OutputURIResolver;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.xml.transform.Result;
import javax.xml.transform.Source;
import javax.xml.transform.Templates;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Map;

/**
 * Applies an XSLT stylesheet (loaded from the classpath) to a FIX Orchestra input file,
 * writing output files to the specified directory via {@code xsl:result-document}.
 *
 * <p>Uses Saxon as the XSLT 2.0 processor. Saxon is invoked through the standard
 * {@link TransformerFactory} JAXP interface; the {@code net.sf.saxon:Saxon-HE} JAR must be
 * present on the classpath.
 */
public class OrchestraTransformer {

    private static final Logger logger = LoggerFactory.getLogger(OrchestraTransformer.class);

    /**
     * Transforms the given input file using the named XSLT stylesheet resource.
     *
     * @param inputFile         FIX Orchestra XML file to transform
     * @param stylesheetResource classpath-relative path of the XSL stylesheet (e.g.
     *                          {@code "xslt/data-dictionary.xsl"})
     * @param outputDir         base directory for generated output files
     * @param params            additional XSLT string parameters (may be {@code null})
     * @throws TransformerException if the transformation fails
     */
    public void transform(File inputFile, String stylesheetResource, File outputDir,
            Map<String, String> params) throws TransformerException {

        TransformerFactory factory = TransformerFactory.newInstance(
                "net.sf.saxon.TransformerFactoryImpl",
                OrchestraTransformer.class.getClassLoader());

        // Configure a result-document resolver that creates parent directories automatically.
        factory.setAttribute(
                "http://saxon.sf.net/feature/outputURIResolver",
                new MkDirOutputURIResolver());

        InputStream xslStream = OrchestraTransformer.class.getClassLoader()
                .getResourceAsStream(stylesheetResource);
        if (xslStream == null) {
            throw new TransformerException(
                    "Stylesheet not found on classpath: " + stylesheetResource);
        }

        // Provide a system-ID so that xsl:include/xsl:import resolves relative to the resource.
        String systemId = OrchestraTransformer.class.getClassLoader()
                .getResource(stylesheetResource).toString();
        Templates templates = factory.newTemplates(new StreamSource(xslStream, systemId));
        Transformer transformer = templates.newTransformer();

        // Always pass the output directory as a file: URI ending with "/".
        String outputDirUri = outputDir.toURI().toString();
        if (!outputDirUri.endsWith("/")) {
            outputDirUri += "/";
        }
        transformer.setParameter("outputDir", outputDirUri);

        if (params != null) {
            for (Map.Entry<String, String> entry : params.entrySet()) {
                transformer.setParameter(entry.getKey(), entry.getValue());
            }
        }

        Source source = new StreamSource(inputFile);
        // The principal output is discarded; all real output goes via xsl:result-document.
        Result discardResult = new StreamResult(new StringWriter());

        logger.debug("Transforming {} with {} → {}", inputFile, stylesheetResource, outputDir);
        transformer.transform(source, discardResult);
    }

    // -------------------------------------------------------------------------
    // Private helper
    // -------------------------------------------------------------------------

    /**
     * Saxon {@link OutputURIResolver} that creates parent directories before opening each
     * result-document output stream.
     */
    private static final class MkDirOutputURIResolver implements OutputURIResolver {

        @Override
        public OutputURIResolver newInstance() {
            return new MkDirOutputURIResolver();
        }

        @Override
        public Result resolve(String href, String base) throws TransformerException {
            try {
                URI uri = (base == null || base.isEmpty())
                        ? new URI(href)
                        : new URI(base).resolve(href);
                File file = new File(uri);
                File parentDir = file.getParentFile();
                if (parentDir != null) {
                    parentDir.mkdirs();
                }
                return new StreamResult(new FileOutputStream(file));
            } catch (URISyntaxException | IOException e) {
                throw new TransformerException(
                        "Cannot open result document for writing: " + href, e);
            }
        }

        @Override
        public void close(Result result) throws TransformerException {
            if (result instanceof StreamResult) {
                java.io.OutputStream stream = ((StreamResult) result).getOutputStream();
                if (stream != null) {
                    try {
                        stream.close();
                    } catch (IOException e) {
                        throw new TransformerException(
                                "Failed to close result document output stream", e);
                    }
                }
            }
        }
    }
}
