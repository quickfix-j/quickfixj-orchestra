<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fixr="http://fixprotocol.io/2020/orchestra/repository"
  xmlns:qfj="urn:quickfixj:xslt"
  exclude-result-prefixes="xs fixr qfj">

  <xsl:include href="common.xsl"/>

  <xsl:output method="text" encoding="UTF-8"/>

  <xsl:param name="outputDir" as="xs:string"/>
  <xsl:param name="generateBigDecimal" as="xs:string" select="'true'"/>
  <xsl:param name="excludeSession" as="xs:string" select="'false'"/>
  <xsl:param name="generateOnlySession" as="xs:string" select="'false'"/>

  <xsl:function name="qfj:boolean-param" as="xs:boolean">
    <xsl:param name="value" as="xs:string"/>
    <xsl:sequence select="lower-case($value) = 'true'"/>
  </xsl:function>

  <xsl:template match="/">
    <xsl:variable name="sessionFieldIds" as="xs:integer*"
      select="distinct-values(for $message in /fixr:repository/fixr:messages/fixr:message[@category = 'Session'] return qfj:collectFieldIds($message/fixr:structure/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], true()))"/>
    <xsl:variable name="allNonSessionFieldIds" as="xs:integer*"
      select="distinct-values(for $message in /fixr:repository/fixr:messages/fixr:message[not(@category = 'Session')] return qfj:collectFieldIds($message/fixr:structure/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], false()))"/>
    <xsl:variable name="nonSessionOnlyFieldIds" as="xs:integer*" select="$allNonSessionFieldIds[not(. = $sessionFieldIds)]"/>
    <xsl:variable name="decimalTypeString" as="xs:string" select="if (qfj:boolean-param($generateBigDecimal)) then 'DecimalField' else 'DoubleField'"/>
    <xsl:variable name="version" as="xs:string" select="qfj:splitOffVersion(string(/fixr:repository/@version))"/>
    <xsl:variable name="extensionPack" as="xs:string" select="qfj:extractExtensionPack(string(/fixr:repository/@version))"/>

    <xsl:for-each select="/fixr:repository/fixr:fields/fixr:field[
      qfj:is-active(., $version, $extensionPack) and
      (qfj:boolean-param($excludeSession) and xs:integer(@id) = $nonSessionOnlyFieldIds)
      or (qfj:boolean-param($generateOnlySession) and xs:integer(@id) = $sessionFieldIds)
      or (not(qfj:boolean-param($excludeSession)) and not(qfj:boolean-param($generateOnlySession)))
    ]">
      <xsl:variable name="name" as="xs:string" select="qfj:toTitleCase(@name)"/>
      <xsl:variable name="codeSet" as="element(fixr:codeSet)?"
        select="key('codeSetByName', @type)[qfj:is-active(., $version, $extensionPack)][1]"/>
      <xsl:variable name="fixType" as="xs:string" select="if ($codeSet) then string($codeSet/@type) else string(@type)"/>
      <xsl:variable name="baseClass" as="xs:string" select="qfj:fieldBaseClass($fixType, $decimalTypeString)"/>
      <xsl:result-document href="{concat($outputDir, 'quickfix/field/', $name, '.java')}" method="text" encoding="UTF-8">
        <xsl:text>/* Generated Java Source File */&#10;</xsl:text>
        <xsl:text>package quickfix.field;&#10;</xsl:text>
        <xsl:if test="$fixType = ('UTCTimestamp', 'UTCTimeOnly', 'UTCDateOnly', 'LocalMktDate', 'LocalMktTime')">
          <xsl:text>import java.time.LocalDate;&#10;</xsl:text>
          <xsl:text>import java.time.LocalTime;&#10;</xsl:text>
          <xsl:text>import java.time.LocalDateTime;&#10;</xsl:text>
        </xsl:if>
        <xsl:if test="$baseClass = 'DecimalField' and qfj:boolean-param($generateBigDecimal)">
          <xsl:text>import java.math.BigDecimal;&#10;</xsl:text>
        </xsl:if>
        <xsl:text>import quickfix.</xsl:text><xsl:value-of select="$baseClass"/><xsl:text>;&#10;</xsl:text>
        <xsl:text>&#10;public class </xsl:text><xsl:value-of select="$name"/><xsl:text> extends </xsl:text><xsl:value-of select="$baseClass"/><xsl:text> {&#10;</xsl:text>
        <xsl:text>  static final long serialVersionUID = 552892318L;&#10;</xsl:text>
        <xsl:text>&#10;  public static final int FIELD = </xsl:text><xsl:value-of select="@id"/><xsl:text>;&#10;</xsl:text>
        <xsl:for-each select="$codeSet/fixr:code[qfj:is-active(., $version, $extensionPack)]">
          <xsl:text>&#10;  public static final </xsl:text>
          <xsl:choose>
            <xsl:when test="$codeSet/@type = 'Boolean'">
              <xsl:text>boolean </xsl:text><xsl:value-of select="qfj:precedeCapsWithUnderscore(@name)"/><xsl:text> = </xsl:text><xsl:value-of select="if (@value = 'Y') then 'true' else 'false'"/><xsl:text>;&#10;</xsl:text>
            </xsl:when>
            <xsl:when test="$codeSet/@type = 'char'">
              <xsl:text>char </xsl:text><xsl:value-of select="qfj:precedeCapsWithUnderscore(@name)"/><xsl:text> = '</xsl:text><xsl:value-of select="@value"/><xsl:text>';&#10;</xsl:text>
            </xsl:when>
            <xsl:when test="$codeSet/@type = 'int'">
              <xsl:text>int </xsl:text><xsl:value-of select="qfj:precedeCapsWithUnderscore(@name)"/><xsl:text> = </xsl:text><xsl:value-of select="@value"/><xsl:text>;&#10;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>String </xsl:text><xsl:value-of select="qfj:precedeCapsWithUnderscore(@name)"/><xsl:text> = "</xsl:text><xsl:value-of select="@value"/><xsl:text>";&#10;</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>() {&#10;    super(</xsl:text><xsl:value-of select="@id"/><xsl:text>);&#10;  }&#10;</xsl:text>
        <xsl:call-template name="field-constructors">
          <xsl:with-param name="name" select="$name"/>
          <xsl:with-param name="fieldId" select="string(@id)"/>
          <xsl:with-param name="baseClass" select="$baseClass"/>
        </xsl:call-template>
        <xsl:text>}&#10;</xsl:text>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="field-constructors">
    <xsl:param name="name" as="xs:string"/>
    <xsl:param name="fieldId" as="xs:string"/>
    <xsl:param name="baseClass" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$baseClass = 'IntField'">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(Integer data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(int data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$baseClass = 'CharField'">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(Character data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(char data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$baseClass = 'BooleanField'">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(Boolean data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(boolean data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$baseClass = 'UtcDateOnlyField'">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(LocalDate data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$baseClass = 'UtcTimeOnlyField'">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(LocalTime data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$baseClass = 'UtcTimeStampField'">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(LocalDateTime data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$baseClass = 'DecimalField' and qfj:boolean-param($generateBigDecimal)">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(BigDecimal data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(double data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, BigDecimal.valueOf(data));&#10;  }&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$baseClass = 'DecimalField' or $baseClass = 'DoubleField'">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(Double data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;    }&#10;</xsl:text>
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(double data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;    }&#10;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>(String data) {&#10;    super(</xsl:text><xsl:value-of select="$fieldId"/><xsl:text>, data);&#10;  }&#10;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
