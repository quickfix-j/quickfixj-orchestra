package org.quickfixj.orchestra;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class CodeGeneratorUtilTest {

    @Test
    void testPrecedeCapsWithUnderscore() {
        assertEquals("CARRIED_NON_CUSTOMER_SIDE_CROSS_MARGINED",
                CodeGeneratorUtil.precedeCapsWithUnderscore("CarriedNonCustomerSideCrossMargined"));
        assertEquals("FIX50SP2",
                CodeGeneratorUtil.precedeCapsWithUnderscore("FIX50SP2"));
        assertEquals("FIX44",
                CodeGeneratorUtil.precedeCapsWithUnderscore("FIX44"));
    }
}
