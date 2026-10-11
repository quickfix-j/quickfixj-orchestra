<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fixr="http://fixprotocol.io/2020/orchestra/repository"
  xmlns:qfj="urn:quickfixj:xslt"
  exclude-result-prefixes="xs fixr qfj">

  <xsl:key name="groupById" match="fixr:group" use="@id"/>
  <xsl:key name="componentById" match="fixr:component" use="@id"/>
  <xsl:key name="fieldById" match="fixr:field" use="@id"/>
  <xsl:key name="codeSetByName" match="fixr:codeSet" use="@name"/>

  <xsl:variable name="allGroups" as="element(fixr:group)*" select="/fixr:repository/fixr:groups/fixr:group"/>
  <xsl:variable name="allComponents" as="element(fixr:component)*" select="/fixr:repository/fixr:components/fixr:component"/>

  <xsl:function name="qfj:indent" as="xs:string">
    <xsl:param name="level" as="xs:integer"/>
    <xsl:sequence select="string-join(for $i in 1 to ($level * 2) return ' ', '')"/>
  </xsl:function>

  <xsl:function name="qfj:fieldBaseClass" as="xs:string">
    <xsl:param name="fixType" as="xs:string"/>
    <xsl:param name="decimalTypeString" as="xs:string"/>
    <xsl:sequence select="
      if ($fixType = 'char') then 'CharField'
      else if ($fixType = ('Price', 'Amt', 'Qty', 'float', 'PriceOffset')) then $decimalTypeString
      else if ($fixType = ('int', 'NumInGroup', 'SeqNum', 'Length', 'TagNum', 'DayOfMonth')) then 'IntField'
      else if ($fixType = 'UTCTimestamp') then 'UtcTimeStampField'
      else if ($fixType = 'UTCTimeOnly') then 'UtcTimeOnlyField'
      else if ($fixType = 'UTCDateOnly') then 'UtcDateOnlyField'
      else if ($fixType = 'Boolean') then 'BooleanField'
      else if ($fixType = 'Percentage') then 'DoubleField'
      else 'StringField'"/>
  </xsl:function>

  <xsl:function name="qfj:collectFieldIds" as="xs:integer*">
    <xsl:param name="members" as="node()*"/>
    <xsl:param name="parseHeaderTrailer" as="xs:boolean"/>
    <xsl:for-each select="$members">
      <xsl:choose>
        <xsl:when test="self::fixr:fieldRef">
          <xsl:sequence select="xs:integer(@id)"/>
        </xsl:when>
        <xsl:when test="self::fixr:groupRef">
          <xsl:variable name="group" as="element(fixr:group)?" select="key('groupById', @id, root(.))[1]"/>
          <xsl:if test="$group">
            <xsl:sequence select="xs:integer($group/fixr:numInGroup/@id)"/>
            <xsl:sequence select="qfj:collectFieldIds($group/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], $parseHeaderTrailer)"/>
          </xsl:if>
        </xsl:when>
        <xsl:when test="self::fixr:componentRef">
          <xsl:variable name="id" as="xs:integer" select="xs:integer(@id)"/>
          <xsl:if test="$parseHeaderTrailer or not($id = (1024, 1025))">
            <xsl:variable name="component" as="element(fixr:component)?" select="key('componentById', @id, root(.))[1]"/>
            <xsl:if test="$component">
              <xsl:sequence select="qfj:collectFieldIds($component/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], $parseHeaderTrailer)"/>
            </xsl:if>
          </xsl:if>
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="qfj:toTitleCase" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="if ($text = '') then '' else concat(upper-case(substring($text, 1, 1)), substring($text, 2))"/>
  </xsl:function>

  <xsl:function name="qfj:getBeginString" as="xs:string">
    <xsl:param name="version" as="xs:string"/>
    <xsl:sequence select="if (starts-with($version, 'FIX.5') or $version = 'FIX.Latest') then 'FIXT.1.1' else $version"/>
  </xsl:function>

  <xsl:function name="qfj:splitOffVersion" as="xs:string">
    <xsl:param name="version" as="xs:string"/>
    <xsl:sequence select="replace($version, '_EP.*$', '')"/>
  </xsl:function>

  <xsl:function name="qfj:extractExtensionPack" as="xs:string">
    <xsl:param name="version" as="xs:string"/>
    <xsl:sequence select="if (matches($version, '_EP[0-9]+$')) then replace($version, '^.*_EP([0-9]+)$', '$1') else '0'"/>
  </xsl:function>

  <xsl:function name="qfj:extractServicePack" as="xs:string">
    <xsl:param name="version" as="xs:string"/>
    <xsl:sequence select="if (matches($version, 'SP[0-9]+')) then replace($version, '^.*SP([0-9]+).*$', '$1') else '0'"/>
  </xsl:function>

  <xsl:function name="qfj:precedeCapsWithUnderscore" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="upper-case(replace($text, '([a-z])([A-Z])', '$1_$2'))"/>
  </xsl:function>
</xsl:stylesheet>
