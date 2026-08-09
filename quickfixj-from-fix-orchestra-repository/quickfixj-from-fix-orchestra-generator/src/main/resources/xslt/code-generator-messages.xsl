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
  <xsl:param name="generateFixt11Package" as="xs:string" select="'true'"/>
  <xsl:param name="excludeSession" as="xs:string" select="'false'"/>
  <xsl:param name="generateOnlySession" as="xs:string" select="'false'"/>

  <xsl:variable name="version" as="xs:string" select="string(/fixr:repository/@version)"/>
  <xsl:variable name="versionBase" as="xs:string" select="qfj:splitOffVersion($version)"/>
  <xsl:variable name="versionPath" as="xs:string" select="lower-case(replace($versionBase, '\.', ''))"/>
  <xsl:variable name="componentPackage" as="xs:string" select="concat('quickfix.', $versionPath, '.component')"/>
  <xsl:variable name="messagePackage" as="xs:string" select="concat('quickfix.', $versionPath)"/>
  <xsl:variable name="fixt11MessagePackage" as="xs:string" select="'quickfix.fixt11'"/>
  <xsl:variable name="fixt11ComponentPackage" as="xs:string" select="'quickfix.fixt11.component'"/>
  <xsl:variable name="sessionMessages" as="element(fixr:message)*" select="/fixr:repository/fixr:messages/fixr:message[@category = 'Session']"/>
  <xsl:variable name="nonSessionMessages" as="element(fixr:message)*" select="/fixr:repository/fixr:messages/fixr:message[not(@category = 'Session')]"/>
  <xsl:variable name="sessionGroupIds" as="xs:integer*"
    select="distinct-values(for $message in $sessionMessages return qfj:collectGroupIds($message/fixr:structure/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], true()))"/>
  <xsl:variable name="nonSessionGroupIds" as="xs:integer*"
    select="distinct-values(for $message in $nonSessionMessages return qfj:collectGroupIds($message/fixr:structure/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], false()))"/>

  <xsl:function name="qfj:boolean-param" as="xs:boolean">
    <xsl:param name="value" as="xs:string"/>
    <xsl:sequence select="lower-case($value) = 'true'"/>
  </xsl:function>

  <xsl:function name="qfj:collectGroupIds" as="xs:integer*">
    <xsl:param name="members" as="node()*"/>
    <xsl:param name="parseHeaderTrailer" as="xs:boolean"/>
    <xsl:for-each select="$members">
      <xsl:choose>
        <xsl:when test="self::fixr:groupRef">
          <xsl:variable name="group" as="element(fixr:group)?" select="key('groupById', @id, root(.))[1]"/>
          <xsl:if test="$group">
            <xsl:sequence select="xs:integer(@id)"/>
            <xsl:sequence select="qfj:collectGroupIds($group/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], $parseHeaderTrailer)"/>
          </xsl:if>
        </xsl:when>
        <xsl:when test="self::fixr:componentRef">
          <xsl:variable name="id" as="xs:integer" select="xs:integer(@id)"/>
          <xsl:if test="$parseHeaderTrailer or not($id = (1024, 1025))">
            <xsl:variable name="component" as="element(fixr:component)?" select="key('componentById', @id, root(.))[1]"/>
            <xsl:if test="$component">
              <xsl:sequence select="qfj:collectGroupIds($component/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef], $parseHeaderTrailer)"/>
            </xsl:if>
          </xsl:if>
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="qfj:getGroupFields" as="xs:integer*">
    <xsl:param name="members" as="node()*"/>
    <xsl:for-each select="$members">
      <xsl:choose>
        <xsl:when test="self::fixr:fieldRef">
          <xsl:sequence select="xs:integer(@id)"/>
        </xsl:when>
        <xsl:when test="self::fixr:groupRef">
          <xsl:variable name="group" as="element(fixr:group)?" select="key('groupById', @id, root(.))[1]"/>
          <xsl:if test="$group">
            <xsl:sequence select="xs:integer($group/fixr:numInGroup/@id)"/>
          </xsl:if>
        </xsl:when>
        <xsl:when test="self::fixr:componentRef">
          <xsl:variable name="component" as="element(fixr:component)?" select="key('componentById', @id, root(.))[1]"/>
          <xsl:if test="$component">
            <xsl:sequence select="qfj:getGroupFields($component/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef])"/>
          </xsl:if>
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="qfj:lower-camel" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="concat(lower-case(substring($text, 1, 1)), substring($text, 2))"/>
  </xsl:function>

  <xsl:function name="qfj:message-class-name" as="xs:string">
    <xsl:param name="message" as="element(fixr:message)"/>
    <xsl:sequence select="if ($message/@scenario = 'base') then string($message/@name) else concat($message/@name, qfj:toTitleCase(string($message/@scenario)))"/>
  </xsl:function>

  <xsl:template match="/">
    <xsl:if test="not(qfj:boolean-param($generateOnlySession))">
      <xsl:for-each select="/fixr:repository/fixr:components/fixr:component[not(@id = ('1024', '1025'))]">
        <xsl:call-template name="generate-component-file">
          <xsl:with-param name="component" select="."/>
          <xsl:with-param name="packageName" select="$componentPackage"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:for-each select="/fixr:repository/fixr:groups/fixr:group[xs:integer(@id) = $nonSessionGroupIds]">
        <xsl:call-template name="generate-group-file">
          <xsl:with-param name="group" select="."/>
          <xsl:with-param name="packageName" select="$componentPackage"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:for-each select="$nonSessionMessages">
        <xsl:call-template name="generate-message-file">
          <xsl:with-param name="message" select="."/>
          <xsl:with-param name="messagePackageName" select="$messagePackage"/>
          <xsl:with-param name="componentPackageName" select="$componentPackage"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:call-template name="generate-message-base-file">
        <xsl:with-param name="packageName" select="$messagePackage"/>
      </xsl:call-template>
      <xsl:call-template name="generate-message-factory-file">
        <xsl:with-param name="packageName" select="$messagePackage"/>
        <xsl:with-param name="messages" select="$nonSessionMessages"/>
      </xsl:call-template>
      <xsl:call-template name="generate-message-cracker-file">
        <xsl:with-param name="packageName" select="$messagePackage"/>
        <xsl:with-param name="messages" select="$nonSessionMessages"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="not(qfj:boolean-param($excludeSession))">
      <xsl:variable name="sessionComponentTarget" as="xs:string" select="if (qfj:boolean-param($generateFixt11Package)) then $fixt11ComponentPackage else $componentPackage"/>
      <xsl:variable name="sessionMessageTarget" as="xs:string" select="if (qfj:boolean-param($generateFixt11Package)) then $fixt11MessagePackage else $messagePackage"/>
      <xsl:for-each select="/fixr:repository/fixr:groups/fixr:group[xs:integer(@id) = $sessionGroupIds]">
        <xsl:call-template name="generate-group-file">
          <xsl:with-param name="group" select="."/>
          <xsl:with-param name="packageName" select="$sessionComponentTarget"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:for-each select="$sessionMessages">
        <xsl:call-template name="generate-message-file">
          <xsl:with-param name="message" select="."/>
          <xsl:with-param name="messagePackageName" select="$sessionMessageTarget"/>
          <xsl:with-param name="componentPackageName" select="$sessionComponentTarget"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:call-template name="generate-message-base-file">
        <xsl:with-param name="packageName" select="$sessionMessageTarget"/>
      </xsl:call-template>
      <xsl:call-template name="generate-message-factory-file">
        <xsl:with-param name="packageName" select="$sessionMessageTarget"/>
        <xsl:with-param name="messages" select="$sessionMessages"/>
      </xsl:call-template>
      <xsl:call-template name="generate-message-cracker-file">
        <xsl:with-param name="packageName" select="$sessionMessageTarget"/>
        <xsl:with-param name="messages" select="$sessionMessages"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template name="generate-component-file">
    <xsl:param name="component" as="element(fixr:component)"/>
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:variable name="name" as="xs:string" select="qfj:toTitleCase(string($component/@name))"/>
    <xsl:variable name="fieldIds" as="xs:integer*" select="$component/fixr:fieldRef/@id ! xs:integer(.)"/>
    <xsl:result-document href="{concat($outputDir, replace($packageName, '\.', '/'), '/', $name, '.java')}" method="text" encoding="UTF-8">
      <xsl:text>/* Generated Java Source File */&#10;</xsl:text>
      <xsl:text>package </xsl:text><xsl:value-of select="$packageName"/><xsl:text>;&#10;</xsl:text>
      <xsl:text>import quickfix.FieldNotFound;&#10;</xsl:text>
      <xsl:text>import quickfix.Group;&#10;</xsl:text>
      <xsl:text>&#10;public class </xsl:text><xsl:value-of select="$name"/><xsl:text> extends quickfix.MessageComponent {&#10;</xsl:text>
      <xsl:text>  static final long serialVersionUID = 552892318L;&#10;</xsl:text>
      <xsl:text>&#10;  public static final String MSGTYPE = "";&#10;</xsl:text>
      <xsl:call-template name="write-component-field-ids">
        <xsl:with-param name="ids" select="$fieldIds"/>
      </xsl:call-template>
      <xsl:call-template name="write-component-group-ids">
        <xsl:with-param name="ids" select="()"/>
      </xsl:call-template>
      <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>() {&#10;    super();&#10;  }&#10;</xsl:text>
      <xsl:call-template name="write-member-accessors">
        <xsl:with-param name="members" select="$component/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef]"/>
        <xsl:with-param name="packageName" select="$packageName"/>
        <xsl:with-param name="componentPackage" select="$packageName"/>
      </xsl:call-template>
      <xsl:text>}&#10;</xsl:text>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="generate-group-file">
    <xsl:param name="group" as="element(fixr:group)"/>
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:variable name="name" as="xs:string" select="qfj:toTitleCase(string($group/@name))"/>
    <xsl:variable name="numInGroupId" as="xs:integer" select="xs:integer($group/fixr:numInGroup/@id)"/>
    <xsl:variable name="numInGroupField" as="element(fixr:field)?" select="key('fieldById', $group/fixr:numInGroup/@id)[1]"/>
    <xsl:result-document href="{concat($outputDir, replace($packageName, '\.', '/'), '/', $name, '.java')}" method="text" encoding="UTF-8">
      <xsl:text>/* Generated Java Source File */&#10;</xsl:text>
      <xsl:text>package </xsl:text><xsl:value-of select="$packageName"/><xsl:text>;&#10;</xsl:text>
      <xsl:text>import quickfix.FieldNotFound;&#10;</xsl:text>
      <xsl:text>import quickfix.Group;&#10;</xsl:text>
      <xsl:text>&#10;public class </xsl:text><xsl:value-of select="$name"/><xsl:text> extends quickfix.MessageComponent {&#10;</xsl:text>
      <xsl:text>  static final long serialVersionUID = 552892318L;&#10;</xsl:text>
      <xsl:text>&#10;  public static final String MSGTYPE = "";&#10;</xsl:text>
      <xsl:call-template name="write-component-field-ids">
        <xsl:with-param name="ids" select="()"/>
      </xsl:call-template>
      <xsl:call-template name="write-component-group-ids">
        <xsl:with-param name="ids" select="$numInGroupId"/>
      </xsl:call-template>
      <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$name"/><xsl:text>() {&#10;    super();&#10;  }&#10;</xsl:text>
      <xsl:if test="$numInGroupField">
        <xsl:call-template name="write-field-accessors">
          <xsl:with-param name="name" select="string($numInGroupField/@name)"/>
          <xsl:with-param name="id" select="$numInGroupId"/>
        </xsl:call-template>
        <xsl:call-template name="write-group-inner-class">
          <xsl:with-param name="group" select="$group"/>
          <xsl:with-param name="packageName" select="$packageName"/>
          <xsl:with-param name="componentPackage" select="$packageName"/>
        </xsl:call-template>
        <xsl:call-template name="write-member-accessors">
          <xsl:with-param name="members" select="$group/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef]"/>
          <xsl:with-param name="packageName" select="$packageName"/>
          <xsl:with-param name="componentPackage" select="$packageName"/>
        </xsl:call-template>
      </xsl:if>
      <xsl:text>}&#10;</xsl:text>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="generate-message-file">
    <xsl:param name="message" as="element(fixr:message)"/>
    <xsl:param name="messagePackageName" as="xs:string"/>
    <xsl:param name="componentPackageName" as="xs:string"/>
    <xsl:variable name="className" as="xs:string" select="qfj:message-class-name($message)"/>
    <xsl:variable name="mandatoryFields" as="element(fixr:field)*"
      select="for $ref in $message/fixr:structure/fixr:fieldRef[@presence = 'required'] return key('fieldById', $ref/@id)[1]"/>
    <xsl:result-document href="{concat($outputDir, replace($messagePackageName, '\.', '/'), '/', $className, '.java')}" method="text" encoding="UTF-8">
      <xsl:text>/* Generated Java Source File */&#10;</xsl:text>
      <xsl:text>package </xsl:text><xsl:value-of select="$messagePackageName"/><xsl:text>;&#10;</xsl:text>
      <xsl:text>import quickfix.FieldNotFound;&#10;</xsl:text>
      <xsl:text>import quickfix.field.*;&#10;</xsl:text>
      <xsl:text>import quickfix.Group;&#10;</xsl:text>
      <xsl:text>&#10;public class </xsl:text><xsl:value-of select="$className"/><xsl:text> extends Message {&#10;</xsl:text>
      <xsl:text>  static final long serialVersionUID = 552892318L;&#10;</xsl:text>
      <xsl:text>&#10;  public static final String MSGTYPE = "</xsl:text><xsl:value-of select="$message/@msgType"/><xsl:text>";&#10;</xsl:text>
      <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$className"/><xsl:text>() {&#10;    super();&#10;    getHeader().setField(new quickfix.field.MsgType(MSGTYPE));&#10;  }&#10;</xsl:text>
      <xsl:if test="exists($mandatoryFields)">
        <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$className"/><xsl:text> (</xsl:text>
        <xsl:for-each select="$mandatoryFields">
          <xsl:if test="position() gt 1"><xsl:text>, </xsl:text></xsl:if>
          <xsl:text>quickfix.field.</xsl:text><xsl:value-of select="@name"/><xsl:text> </xsl:text><xsl:value-of select="qfj:lower-camel(string(@name))"/>
        </xsl:for-each>
        <xsl:text>) {&#10;    this();&#10;</xsl:text>
        <xsl:for-each select="$mandatoryFields">
          <xsl:text>    setField(</xsl:text><xsl:value-of select="qfj:lower-camel(string(@name))"/><xsl:text>);&#10;</xsl:text>
        </xsl:for-each>
        <xsl:text>  }&#10;</xsl:text>
      </xsl:if>
      <xsl:call-template name="write-member-accessors">
        <xsl:with-param name="members" select="$message/fixr:structure/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef]"/>
        <xsl:with-param name="packageName" select="$messagePackageName"/>
        <xsl:with-param name="componentPackage" select="$componentPackageName"/>
      </xsl:call-template>
      <xsl:text>}&#10;</xsl:text>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="generate-message-base-file">
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:result-document href="{concat($outputDir, replace($packageName, '\.', '/'), '/Message.java')}" method="text" encoding="UTF-8">
      <xsl:text>/* Generated Java Source File */&#10;</xsl:text>
      <xsl:text>package </xsl:text><xsl:value-of select="$packageName"/><xsl:text>;&#10;</xsl:text>
      <xsl:text>import quickfix.field.*;&#10;</xsl:text>
      <xsl:text>&#10;public class Message extends quickfix.Message {&#10;</xsl:text>
      <xsl:text>  static final long serialVersionUID = 552892318L;&#10;</xsl:text>
      <xsl:text>&#10;  public Message() {&#10;    this(null);&#10;  }&#10;</xsl:text>
      <xsl:text>  protected Message(int[] fieldOrder) {&#10;    super(fieldOrder);&#10;    header = new Header(this);&#10;    trailer = new Trailer();&#10;    getHeader().setField(new BeginString("</xsl:text><xsl:value-of select="qfj:getBeginString(qfj:splitOffVersion($version))"/><xsl:text>"));&#10;  }&#10;</xsl:text>
      <xsl:text>&#10;  @Override&#10;  protected Header newHeader() {&#10;    return new Header(this);&#10;  }&#10;</xsl:text>
      <xsl:text>&#10;  @Override&#10;  public Header getHeader() {&#10;    return (Message.Header)header;&#10;  }&#10;</xsl:text>
      <xsl:text>&#10;public static class Header extends quickfix.Message.Header {&#10;  static final long serialVersionUID = 552892318L;&#10;</xsl:text>
      <xsl:text>&#10;  public Header(Message msg) {&#10;&#10;  }&#10;}&#10;}&#10;</xsl:text>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="generate-message-cracker-file">
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:param name="messages" as="element(fixr:message)*"/>
    <xsl:variable name="crackMethodName" as="xs:string" select="concat('crack', tokenize($packageName, '\.')[2])"/>
    <xsl:result-document href="{concat($outputDir, replace($packageName, '\.', '/'), '/MessageCracker.java')}" method="text" encoding="UTF-8">
      <xsl:text>/* Generated Java Source File */&#10;</xsl:text>
      <xsl:text>package </xsl:text><xsl:value-of select="$packageName"/><xsl:text>;&#10;</xsl:text>
      <xsl:text>import quickfix.*;&#10;</xsl:text>
      <xsl:text>import quickfix.field.*;&#10;</xsl:text>
      <xsl:text>&#10;public class MessageCracker {&#10;</xsl:text>
      <xsl:text>&#10;  public void onMessage(quickfix.Message message, SessionID sessionID) throws FieldNotFound, UnsupportedMessageType, IncorrectTagValue {&#10;    throw new UnsupportedMessageType();&#10;  }&#10;</xsl:text>
      <xsl:for-each select="$messages[@scenario = 'base']">
        <xsl:text>  /**&#10;   * Callback for </xsl:text><xsl:value-of select="@name"/><xsl:text> message.&#10;   * @param message&#10;   * @param sessionID&#10;   * @throws FieldNotFound&#10;   * @throws UnsupportedMessageType&#10;   * @throws IncorrectTagValue&#10;   */&#10;</xsl:text>
        <xsl:text>&#10;  public void onMessage(</xsl:text><xsl:value-of select="@name"/><xsl:text> message, SessionID sessionID) throws FieldNotFound, UnsupportedMessageType, IncorrectTagValue {&#10;    throw new UnsupportedMessageType();&#10;  }&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>&#10;  public void crack(quickfix.Message message, SessionID sessionID)&#10;    throws UnsupportedMessageType, FieldNotFound, IncorrectTagValue {&#10;    </xsl:text><xsl:value-of select="$crackMethodName"/><xsl:text>((Message) message, sessionID);&#10;  }&#10;</xsl:text>
      <xsl:text>&#10;  public void </xsl:text><xsl:value-of select="$crackMethodName"/><xsl:text>(Message message, SessionID sessionID)&#10;    throws UnsupportedMessageType, FieldNotFound, IncorrectTagValue {&#10;    String type = message.getHeader().getString(MsgType.FIELD);&#10;    switch (type) {&#10;</xsl:text>
      <xsl:for-each select="$messages[@scenario = 'base']">
        <xsl:text>    case </xsl:text><xsl:value-of select="@name"/><xsl:text>.MSGTYPE:&#10;      onMessage((</xsl:text><xsl:value-of select="@name"/><xsl:text>)message, sessionID);&#10;      break;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>    default:&#10;      onMessage(message, sessionID);&#10;    }&#10;  }&#10;}&#10;</xsl:text>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="generate-message-factory-file">
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:param name="messages" as="element(fixr:message)*"/>
    <xsl:result-document href="{concat($outputDir, replace($packageName, '\.', '/'), '/MessageFactory.java')}" method="text" encoding="UTF-8">
      <xsl:text>/* Generated Java Source File */&#10;</xsl:text>
      <xsl:text>package </xsl:text><xsl:value-of select="$packageName"/><xsl:text>;&#10;</xsl:text>
      <xsl:text>import quickfix.Message;&#10;</xsl:text>
      <xsl:text>import quickfix.Group;&#10;</xsl:text>
      <xsl:text>&#10;public class MessageFactory implements quickfix.MessageFactory {&#10;</xsl:text>
      <xsl:text>&#10;  public Message create(String beginString, String msgType) {&#10;    switch (msgType) {&#10;</xsl:text>
      <xsl:for-each select="$messages[@scenario = 'base']">
        <xsl:text>    case </xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="@name"/><xsl:text>.MSGTYPE:&#10;      return new </xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="@name"/><xsl:text>();&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>    }&#10;    return new </xsl:text><xsl:value-of select="$packageName"/><xsl:text>.Message();&#10;  }&#10;</xsl:text>
      <xsl:text>&#10;  public Group create(String beginString, String msgType, int correspondingFieldID) {&#10;    switch (msgType) {&#10;</xsl:text>
      <xsl:for-each select="$messages[@scenario = 'base']">
        <xsl:text>  case </xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="@name"/><xsl:text>.MSGTYPE:&#10;    switch (correspondingFieldID) {&#10;</xsl:text>
        <xsl:for-each select="fixr:structure/fixr:groupRef">
          <xsl:variable name="group" as="element(fixr:group)?" select="key('groupById', @id)[1]"/>
          <xsl:if test="$group">
            <xsl:call-template name="write-group-create-case">
              <xsl:with-param name="parentQualifiedName" select="concat($packageName, '.', current()/../@name)"/>
              <xsl:with-param name="group" select="$group"/>
            </xsl:call-template>
          </xsl:if>
        </xsl:for-each>
        <xsl:text>    }&#10;    break;&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>    }&#10;    return null;&#10;  }&#10;}&#10;</xsl:text>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="write-group-create-case">
    <xsl:param name="parentQualifiedName" as="xs:string"/>
    <xsl:param name="group" as="element(fixr:group)"/>
    <xsl:variable name="numField" as="element(fixr:field)?" select="key('fieldById', $group/fixr:numInGroup/@id)[1]"/>
    <xsl:if test="$numField">
      <xsl:text>      case quickfix.field.</xsl:text><xsl:value-of select="$numField/@name"/><xsl:text>.FIELD:&#10;        return new </xsl:text><xsl:value-of select="$parentQualifiedName"/><xsl:text>.</xsl:text><xsl:value-of select="$numField/@name"/><xsl:text>();&#10;</xsl:text>
      <xsl:for-each select="$group/fixr:groupRef">
        <xsl:variable name="nestedGroup" as="element(fixr:group)?" select="key('groupById', @id)[1]"/>
        <xsl:if test="$nestedGroup">
          <xsl:call-template name="write-group-create-case">
            <xsl:with-param name="parentQualifiedName" select="concat($parentQualifiedName, '.', $numField/@name)"/>
            <xsl:with-param name="group" select="$nestedGroup"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <xsl:template name="write-component-field-ids">
    <xsl:param name="ids" as="xs:integer*"/>
    <xsl:text>  private int[] componentFields = {</xsl:text>
    <xsl:for-each select="$ids"><xsl:value-of select="concat(., ', ')"/></xsl:for-each>
    <xsl:text>};&#10;  protected int[] getFields() { return componentFields; }&#10;</xsl:text>
  </xsl:template>

  <xsl:template name="write-component-group-ids">
    <xsl:param name="ids" as="xs:integer*"/>
    <xsl:text>  private int[] componentGroups = {</xsl:text>
    <xsl:for-each select="$ids"><xsl:value-of select="concat(., ', ')"/></xsl:for-each>
    <xsl:text>};&#10;  protected int[] getGroupFields() { return componentGroups; }&#10;</xsl:text>
  </xsl:template>

  <xsl:template name="write-order-field-ids">
    <xsl:param name="ids" as="xs:integer*"/>
    <xsl:text>  private static final int[]  ORDER = {</xsl:text>
    <xsl:for-each select="$ids"><xsl:value-of select="concat(., ', ')"/></xsl:for-each>
    <xsl:text>0};&#10;</xsl:text>
  </xsl:template>

  <xsl:template name="write-field-accessors">
    <xsl:param name="name" as="xs:string"/>
    <xsl:param name="id" as="xs:integer"/>
    <xsl:text>&#10;  public void set(quickfix.field.</xsl:text><xsl:value-of select="$name"/><xsl:text> value) {&#10;    setField(value);&#10;  }&#10;</xsl:text>
    <xsl:text>&#10;  public quickfix.field.</xsl:text><xsl:value-of select="$name"/><xsl:text> get(quickfix.field.</xsl:text><xsl:value-of select="$name"/><xsl:text> value) throws FieldNotFound {&#10;    getField(value);&#10;    return value;&#10;  }&#10;</xsl:text>
    <xsl:text>&#10;  public quickfix.field.</xsl:text><xsl:value-of select="$name"/><xsl:text> get</xsl:text><xsl:value-of select="$name"/><xsl:text>() throws FieldNotFound {&#10;    return get(new quickfix.field.</xsl:text><xsl:value-of select="$name"/><xsl:text>());&#10;  }&#10;</xsl:text>
    <xsl:text>&#10;  public boolean isSet(quickfix.field.</xsl:text><xsl:value-of select="$name"/><xsl:text> field) {&#10;    return isSetField(field);&#10;  }&#10;</xsl:text>
    <xsl:text>&#10;  public boolean isSet</xsl:text><xsl:value-of select="$name"/><xsl:text>() {&#10;    return isSetField(</xsl:text><xsl:value-of select="$id"/><xsl:text>);&#10;  }&#10;</xsl:text>
  </xsl:template>

  <xsl:template name="write-component-accessors">
    <xsl:param name="componentName" as="xs:string"/>
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:if test="not($componentName = ('StandardHeader', 'StandardTrailer'))">
      <xsl:text>&#10;  public void set(</xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="$componentName"/><xsl:text> component) {&#10;    setComponent(component);&#10;  }&#10;</xsl:text>
      <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="$componentName"/><xsl:text> get(</xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="$componentName"/><xsl:text> component) throws FieldNotFound {&#10;    getComponent(component);&#10;    return component;&#10;  }&#10;</xsl:text>
      <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="$componentName"/><xsl:text> get</xsl:text><xsl:value-of select="$componentName"/><xsl:text>Component() throws FieldNotFound {&#10;    return get(new </xsl:text><xsl:value-of select="$packageName"/><xsl:text>.</xsl:text><xsl:value-of select="$componentName"/><xsl:text>());&#10;  }&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="write-group-inner-class">
    <xsl:param name="group" as="element(fixr:group)"/>
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:param name="componentPackage" as="xs:string"/>
    <xsl:variable name="numInGroupId" as="xs:integer" select="xs:integer($group/fixr:numInGroup/@id)"/>
    <xsl:variable name="numField" as="element(fixr:field)?" select="key('fieldById', $group/fixr:numInGroup/@id)[1]"/>
    <xsl:variable name="orderIds" as="xs:integer*" select="qfj:getGroupFields($group/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef])"/>
    <xsl:if test="$numField">
      <xsl:text>&#10;public static class </xsl:text><xsl:value-of select="$numField/@name"/><xsl:text> extends Group {&#10;  static final long serialVersionUID = 552892318L;&#10;</xsl:text>
      <xsl:call-template name="write-order-field-ids">
        <xsl:with-param name="ids" select="$orderIds"/>
      </xsl:call-template>
      <xsl:text>&#10;  public </xsl:text><xsl:value-of select="$numField/@name"/><xsl:text>() {&#10;    super(</xsl:text><xsl:value-of select="$numInGroupId"/><xsl:text>, </xsl:text><xsl:value-of select="($orderIds[1], 0)[1]"/><xsl:text>, ORDER);&#10;  }&#10;</xsl:text>
      <xsl:call-template name="write-member-accessors">
        <xsl:with-param name="members" select="$group/*[self::fixr:fieldRef or self::fixr:componentRef or self::fixr:groupRef]"/>
        <xsl:with-param name="packageName" select="$packageName"/>
        <xsl:with-param name="componentPackage" select="$componentPackage"/>
      </xsl:call-template>
      <xsl:text>}&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template name="write-member-accessors">
    <xsl:param name="members" as="node()*"/>
    <xsl:param name="packageName" as="xs:string"/>
    <xsl:param name="componentPackage" as="xs:string"/>
    <xsl:for-each select="$members">
      <xsl:choose>
        <xsl:when test="self::fixr:fieldRef">
          <xsl:variable name="field" as="element(fixr:field)?" select="key('fieldById', @id)[1]"/>
          <xsl:if test="$field">
            <xsl:call-template name="write-field-accessors">
              <xsl:with-param name="name" select="string($field/@name)"/>
              <xsl:with-param name="id" select="xs:integer(@id)"/>
            </xsl:call-template>
          </xsl:if>
        </xsl:when>
        <xsl:when test="self::fixr:groupRef">
          <xsl:variable name="group" as="element(fixr:group)?" select="key('groupById', @id)[1]"/>
          <xsl:if test="$group">
            <xsl:call-template name="write-component-accessors">
              <xsl:with-param name="componentName" select="string($group/@name)"/>
              <xsl:with-param name="packageName" select="$componentPackage"/>
            </xsl:call-template>
            <xsl:variable name="numInGroupId" as="xs:integer" select="xs:integer($group/fixr:numInGroup/@id)"/>
            <xsl:variable name="numField" as="element(fixr:field)?" select="key('fieldById', $group/fixr:numInGroup/@id)[1]"/>
            <xsl:if test="$numField">
              <xsl:call-template name="write-field-accessors">
                <xsl:with-param name="name" select="string($numField/@name)"/>
                <xsl:with-param name="id" select="$numInGroupId"/>
              </xsl:call-template>
              <xsl:call-template name="write-group-inner-class">
                <xsl:with-param name="group" select="$group"/>
                <xsl:with-param name="packageName" select="$packageName"/>
                <xsl:with-param name="componentPackage" select="$componentPackage"/>
              </xsl:call-template>
            </xsl:if>
          </xsl:if>
        </xsl:when>
        <xsl:when test="self::fixr:componentRef">
          <xsl:variable name="component" as="element(fixr:component)?" select="key('componentById', @id)[1]"/>
          <xsl:if test="$component">
            <xsl:call-template name="write-component-accessors">
              <xsl:with-param name="componentName" select="string($component/@name)"/>
              <xsl:with-param name="packageName" select="$componentPackage"/>
            </xsl:call-template>
          </xsl:if>
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
