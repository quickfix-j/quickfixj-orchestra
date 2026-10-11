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

  <xsl:variable name="requiredGroupIds" as="xs:integer*"
    select="distinct-values(/fixr:repository//fixr:groupRef[@presence = 'required']/@id ! xs:integer(.))"/>

  <xsl:function name="qfj:required-flag" as="xs:string">
    <xsl:param name="presence" as="xs:string?"/>
    <xsl:sequence select="if ($presence = 'required') then 'Y' else 'N'"/>
  </xsl:function>

  <xsl:template match="/">
    <xsl:variable name="version" as="xs:string" select="string(/fixr:repository/@version)"/>
    <xsl:variable name="fileName" as="xs:string" select="qfj:splitOffVersion($version)"/>
    <xsl:variable name="servicePack" as="xs:string" select="qfj:extractServicePack($version)"/>
    <xsl:variable name="extensionPack" as="xs:string" select="qfj:extractExtensionPack($version)"/>
    <xsl:variable name="versionPath" as="xs:string" select="replace($fileName, '\.', '')"/>
    <xsl:variable name="major" as="xs:string" select="if ($fileName = 'FIX.Latest') then 'Latest' else replace($fileName, '^FIX\.([0-9]+)\..*$', '$1')"/>
    <xsl:variable name="minor" as="xs:string" select="if ($fileName = 'FIX.Latest') then '0' else replace($fileName, '^FIX\.[0-9]+\.([0-9]+).*$' , '$1')"/>
    <xsl:result-document href="{concat($outputDir, $versionPath, '.xml')}" method="text" encoding="UTF-8">
      <xsl:text>&lt;fix major="</xsl:text><xsl:value-of select="$major"/><xsl:text>" minor="</xsl:text><xsl:value-of select="$minor"/><xsl:text>" servicepack="</xsl:text><xsl:value-of select="$servicePack"/><xsl:text>" extensionpack="</xsl:text><xsl:value-of select="$extensionPack"/><xsl:text>"&gt;&#10;</xsl:text>
      <xsl:text>  &lt;header/>&#10;</xsl:text>
      <xsl:text>  &lt;trailer/>&#10;</xsl:text>
      <xsl:text>  &lt;messages&gt;&#10;</xsl:text>
      <xsl:for-each select="/fixr:repository/fixr:messages/fixr:message">
        <xsl:variable name="isAdminMessage" as="xs:boolean" select="@category = 'Session'"/>
        <xsl:text>    &lt;message name="</xsl:text><xsl:value-of select="@name"/><xsl:text>" msgtype="</xsl:text><xsl:value-of select="@msgType"/><xsl:text>" msgcat="</xsl:text><xsl:value-of select="if ($isAdminMessage) then 'admin' else 'app'"/><xsl:text>"&gt;&#10;</xsl:text>
        <xsl:call-template name="dd-write-members">
          <xsl:with-param name="members" select="fixr:structure/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef]"/>
          <xsl:with-param name="skipHeaderTrailer" select="true()"/>
          <xsl:with-param name="skipAdminComponents" select="not($isAdminMessage)"/>
        </xsl:call-template>
        <xsl:text>    &lt;/message&gt;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>  &lt;/messages&gt;&#10;</xsl:text>
      <xsl:text>  &lt;components&gt;&#10;</xsl:text>
      <xsl:for-each select="/fixr:repository/fixr:components/fixr:component">
        <xsl:text>    &lt;component name="</xsl:text><xsl:value-of select="@name"/><xsl:text>"&gt;&#10;</xsl:text>
        <xsl:call-template name="dd-write-members">
          <xsl:with-param name="members" select="*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef]"/>
          <xsl:with-param name="skipHeaderTrailer" select="false()"/>
          <xsl:with-param name="skipAdminComponents" select="false()"/>
        </xsl:call-template>
        <xsl:text>    &lt;/component&gt;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:for-each select="/fixr:repository/fixr:groups/fixr:group">
        <xsl:variable name="numInGroupField" as="element(fixr:field)?" select="key('fieldById', fixr:numInGroup/@id)[1]"/>
        <xsl:text>    &lt;component name="</xsl:text><xsl:value-of select="@name"/><xsl:text>"&gt;&#10;</xsl:text>
        <xsl:text>      &lt;group name="</xsl:text><xsl:value-of select="$numInGroupField/@name"/><xsl:text>" required="</xsl:text><xsl:value-of select="if (xs:integer(@id) = $requiredGroupIds) then 'Y' else 'N'"/><xsl:text>"&gt;&#10;</xsl:text>
        <xsl:call-template name="dd-write-members">
          <xsl:with-param name="members" select="*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef]"/>
          <xsl:with-param name="skipHeaderTrailer" select="false()"/>
          <xsl:with-param name="skipAdminComponents" select="false()"/>
        </xsl:call-template>
        <xsl:text>      &lt;/group&gt;&#10;</xsl:text>
        <xsl:text>    &lt;/component&gt;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>  &lt;/components&gt;&#10;</xsl:text>
      <xsl:text>  &lt;fields&gt;&#10;</xsl:text>
      <xsl:for-each select="/fixr:repository/fixr:fields/fixr:field">
        <xsl:variable name="codeSet" as="element(fixr:codeSet)?" select="key('codeSetByName', @type)[1]"/>
        <xsl:variable name="fixType" as="xs:string" select="upper-case(if ($codeSet) then string($codeSet/@type) else string(@type))"/>
        <xsl:text>    &lt;field number="</xsl:text><xsl:value-of select="@id"/><xsl:text>" name="</xsl:text><xsl:value-of select="@name"/><xsl:text>" type="</xsl:text><xsl:value-of select="$fixType"/>
        <xsl:choose>
          <xsl:when test="$codeSet">
            <xsl:text>"&gt;&#10;</xsl:text>
            <xsl:for-each select="$codeSet/fixr:code">
              <xsl:text>      &lt;value enum="</xsl:text><xsl:value-of select="@value"/><xsl:text>" description="</xsl:text><xsl:value-of select="qfj:precedeCapsWithUnderscore(@name)"/><xsl:text>"/>&#10;</xsl:text>
            </xsl:for-each>
            <xsl:text>    &lt;/field&gt;&#10;</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>"/>&#10;</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
      <xsl:text>  &lt;/fields&gt;&#10;</xsl:text>
      <xsl:text>&lt;/fix&gt;&#10;</xsl:text>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="dd-write-members">
    <xsl:param name="members" as="node()*"/>
    <xsl:param name="skipHeaderTrailer" as="xs:boolean"/>
    <xsl:param name="skipAdminComponents" as="xs:boolean"/>
    <xsl:for-each select="$members">
      <xsl:choose>
        <xsl:when test="self::fixr:fieldRef">
          <xsl:variable name="field" as="element(fixr:field)?" select="key('fieldById', @id)[1]"/>
          <xsl:if test="$field">
            <xsl:text>      &lt;field name="</xsl:text><xsl:value-of select="$field/@name"/><xsl:text>" required="</xsl:text><xsl:value-of select="qfj:required-flag(@presence)"/><xsl:text>"/>&#10;</xsl:text>
          </xsl:if>
        </xsl:when>
        <xsl:when test="self::fixr:groupRef">
          <xsl:variable name="group" as="element(fixr:group)?" select="key('groupById', @id)[1]"/>
          <xsl:if test="$group">
            <xsl:text>      &lt;component name="</xsl:text><xsl:value-of select="$group/@name"/><xsl:text>" required="</xsl:text><xsl:value-of select="qfj:required-flag(@presence)"/><xsl:text>"/>&#10;</xsl:text>
          </xsl:if>
        </xsl:when>
        <xsl:when test="self::fixr:componentRef">
          <xsl:variable name="component" as="element(fixr:component)?" select="key('componentById', @id)[1]"/>
          <xsl:if test="$component and not($skipHeaderTrailer and @id = ('1024', '1025')) and not($skipAdminComponents and $component/@category = 'Session')">
            <xsl:text>      &lt;component name="</xsl:text><xsl:value-of select="$component/@name"/><xsl:text>" required="</xsl:text><xsl:value-of select="qfj:required-flag(@presence)"/><xsl:text>"/>&#10;</xsl:text>
          </xsl:if>
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
