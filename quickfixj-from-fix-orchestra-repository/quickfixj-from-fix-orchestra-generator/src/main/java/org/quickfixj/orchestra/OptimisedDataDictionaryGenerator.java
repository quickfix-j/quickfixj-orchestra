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

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.Writer;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;
import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;
import javax.xml.bind.Unmarshaller;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpression;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;
import io.fixprotocol._2020.orchestra.repository.Repository;
import javax.xml.namespace.NamespaceContext;

/**
 * A performance-optimised variant of {@link DataDictionaryGenerator} that avoids the three main
 * sources of per-call overhead identified before PR #68:
 *
 * <ol>
 *   <li><strong>Static {@link JAXBContext}</strong> – a single context is initialised at
 *       class-load time and reused for every invocation. Creating a {@code JAXBContext} triggers
 *       an expensive classpath scan; reusing it eliminates that cost.</li>
 *   <li><strong>Thread-local {@link XPathExpression}</strong> – the XPath expression used to
 *       locate required groups is compiled once per thread and cached in a
 *       {@link ThreadLocal}. {@code XPathExpression} is <em>not</em> thread-safe, so a per-thread
 *       instance is used rather than a single static field.</li>
 *   <li><strong>Buffered file I/O</strong> – the output {@link Writer} is wrapped in a
 *       {@link BufferedWriter}, reducing the number of system calls for small writes.</li>
 * </ol>
 */
public class OptimisedDataDictionaryGenerator extends DataDictionaryGenerator {

    // -------------------------------------------------------------------------
    // Shared, thread-safe resources
    // -------------------------------------------------------------------------

    private static final JAXBContext SHARED_JAXB_CONTEXT;

    static {
        try {
            SHARED_JAXB_CONTEXT = JAXBContext.newInstance(Repository.class);
        } catch (JAXBException e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    /**
     * Namespace context used when compiling the XPath expression.
     * The instance is stateless and therefore safe to share.
     */
    private static final NamespaceContext FIXR_NAMESPACE_CONTEXT = new NamespaceContext() {
        @Override
        public String getNamespaceURI(String prefix) {
            if ("fixr".equals(prefix)) {
                return "http://fixprotocol.io/2020/orchestra/repository";
            }
            return null;
        }

        @Override
        public String getPrefix(String namespaceURI) {
            return null;
        }

        @Override
        public Iterator<String> getPrefixes(String namespaceURI) {
            return null;
        }
    };

    /**
     * Per-thread compiled XPath expression.
     *
     * <p>{@code XPathExpression} is not thread-safe, so a {@link ThreadLocal} is used to give
     * each thread its own compiled instance rather than re-compiling on every call.
     */
    private static final ThreadLocal<XPathExpression> REQUIRED_GROUPS_EXPR =
            new ThreadLocal<XPathExpression>() {
                @Override
                protected XPathExpression initialValue() {
                    try {
                        XPath xPath = XPathFactory.newInstance().newXPath();
                        xPath.setNamespaceContext(FIXR_NAMESPACE_CONTEXT);
                        return xPath.compile("//fixr:groupRef[@presence='required']");
                    } catch (XPathExpressionException e) {
                        throw new RuntimeException("Failed to compile XPath expression", e);
                    }
                }
            };

    // -------------------------------------------------------------------------
    // Overrides
    // -------------------------------------------------------------------------

    /**
     * Uses the shared {@link JAXBContext} instead of creating a new one on every call.
     */
    @Override
    protected UnmarshalResult unmarshal(InputStream inputFile)
            throws JAXBException, ParserConfigurationException, SAXException, IOException {
        DocumentBuilderFactory builderFactory = DocumentBuilderFactory.newInstance();
        builderFactory.setNamespaceAware(true);
        DocumentBuilder builder = builderFactory.newDocumentBuilder();
        Document document = builder.parse(inputFile);
        Unmarshaller jaxbUnmarshaller = SHARED_JAXB_CONTEXT.createUnmarshaller();
        Repository repository = (Repository) jaxbUnmarshaller.unmarshal(document);
        return new UnmarshalResult(repository, document.getDocumentElement());
    }

    /**
     * Uses the per-thread cached {@link XPathExpression} instead of compiling a new one on
     * every call.
     */
    @Override
    protected Set<Integer> getRequiredGroups(Node repositoryNode) throws XPathExpressionException {
        Set<Integer> groupIds = new HashSet<Integer>();
        NodeList nodeList = (NodeList) REQUIRED_GROUPS_EXPR.get()
                .evaluate(repositoryNode, XPathConstants.NODESET);
        for (int i = 0; i < nodeList.getLength(); i++) {
            if (nodeList.item(i).getNodeType() == Node.ELEMENT_NODE) {
                Element element = (Element) nodeList.item(i);
                String id = element.getAttribute("id");
                groupIds.add(Integer.parseInt(id));
            }
        }
        return groupIds;
    }

    /**
     * Wraps the output {@link FileWriter} in a {@link BufferedWriter} to reduce the number of
     * kernel write calls.
     */
    @Override
    protected Writer createWriter(File file) throws IOException {
        return new BufferedWriter(new FileWriter(file));
    }
}
