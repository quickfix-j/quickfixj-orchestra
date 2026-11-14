package org.quickfixj.orchestra;

public class CodeGeneratorUtil {

    public static String precedeCapsWithUnderscore(String stringToTransform) {
        return stringToTransform.replaceAll("([a-z])([A-Z])", "$1_$2").toUpperCase();
    }

}
