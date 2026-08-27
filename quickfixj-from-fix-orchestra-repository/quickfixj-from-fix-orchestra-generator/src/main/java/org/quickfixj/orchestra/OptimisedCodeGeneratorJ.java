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

import java.io.InputStream;
import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;
import io.fixprotocol._2020.orchestra.repository.Repository;

/**
 * A performance-optimised variant of {@link CodeGeneratorJ} that avoids the cost of
 * re-creating a {@link JAXBContext} on every call to {@link #generate}.
 *
 * <p><strong>Optimisation applied</strong>
 * <ul>
 *   <li>A single {@code JAXBContext} is initialised once at class-load time and reused for every
 *       invocation. Creating a {@code JAXBContext} triggers a classpath scan which is expensive;
 *       reusing it reduces per-call overhead significantly.</li>
 * </ul>
 *
 * <p>{@code JAXBContext} is specified as thread-safe, so the shared instance may safely be used
 * from multiple threads simultaneously.
 */
public class OptimisedCodeGeneratorJ extends CodeGeneratorJ {

    private static final JAXBContext SHARED_JAXB_CONTEXT;

    static {
        try {
            SHARED_JAXB_CONTEXT = JAXBContext.newInstance(Repository.class);
        } catch (JAXBException e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    /**
     * Overrides the base-class unmarshal step to use the shared, pre-initialised
     * {@link JAXBContext} rather than creating a new one on every invocation.
     */
    @Override
    protected void initialise(InputStream inputFile) throws JAXBException {
        this.repository = (Repository) SHARED_JAXB_CONTEXT.createUnmarshaller().unmarshal(inputFile);
    }
}
