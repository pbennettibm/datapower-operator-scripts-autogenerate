<?xml version="1.0" encoding="UTF-8"?>
<!-- 

  This stylesheet contains functions to handle the "userid" for the request when it
  was supplied as an X509 certificate in a binary security token, as a userid in a
  username token, or as a basic auth userid.

04/23/2013  Modified error codes and support codes

-->
<xsl:stylesheet version="1.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:date="http://exslt.org/dates-and-times"
  xmlns:dp="http://www.datapower.com/extensions" 
  xmlns:dpconfig="http://www.datapower.com/param/config" 
  xmlns:dpquery="http://www.datapower.com/param/query" 
  xmlns:dsig="http://www.w3.org/2000/09/xmldsig#"
  xmlns:dyn="http://exslt.org/dynamic"
  xmlns:exslt="http://exslt.org/common"
  xmlns:func="http://exslt.org/functions"
  xmlns:local="urn:local:function"
  xmlns:mgmt="http://www.datapower.com/schemas/management"
  xmlns:regexp="http://exslt.org/regular-expressions"
  xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
  xmlns:str="http://exslt.org/strings"
  xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  xmlns:ds="http://www.w3.org/2000/09/xmldsig#" 
  extension-element-prefixes="date dp dyn exslt func regexp str" 
  exclude-result-prefixes="date dp dpconfig dpquery dyn exslt func regexp str">

<!--Supports Binary Token and X509 Certificate-->
<xsl:variable name="X509v3" select="'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3'"/> 
<!--Supports Binary with a Path of Certificates-->
<xsl:variable name="X509PKIPathv1" select="'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509PKIPathv1'"/> 
<!--Subject Key Identifier-->
<xsl:variable name="X509SubjectKeyIdentifier" select="'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509SubjectKeyIdentifier'"/>
<!--Issuer Name and Serial Number-->
<xsl:variable name="X509IssuerName" select="'/wsse:Security/wsse:SecurityTokenReference'"/>


  <xsl:variable name="aaa" select="dp:variable('var://context/ActiveMatrixESB/aaa')" /> 
  <xsl:variable name="valcred" select="$aaa/aaa/@valcred"/>
  <!--<xsl:variable name="errorCode" select="dp:variable('var://service/error-code')"/>
  <xsl:variable name="errorSubCode" select="dp:variable('var://service/error-subcode')"/>-->
  <xsl:variable name="ldapHostname" select="'LDAP-PRD.delta.com'"/>
  <xsl:variable name="ldapPort" select="'389'"/>
  <xsl:variable name="ldapId" select="'svcdpw'"/>
  <xsl:variable name="ldapPwd" select="'SVC2jT4d'"/>
  
  <xsl:template match="/">
    
    <xsl:element name="result">
		<!--This set of functions only return a True or False-->
      <xsl:element name="isIdX509">
        <xsl:value-of select="local:isIdX509(.)"/>
      </xsl:element>
      
      <xsl:element name="isIdUsernameToken">
        <xsl:value-of select="local:isIdUsernameToken(.)"/>
      </xsl:element>
      
      <xsl:element name="isIdBasicAuth">
        <xsl:value-of select="local:isIdBasicAuth()"/>
      </xsl:element>
      <!--End set of functions only return a True or False-->

      <xsl:element name="getIdDN">
        <xsl:value-of select="local:getIdDN(.)"/>
      </xsl:element>
      

	  <!--These functions get more details about the Identification used in Authentication-->
      <xsl:element name="getIdUNT">
        <xsl:value-of select="local:getIdUNT(.)"/>
      </xsl:element>
      
      <xsl:element name="getIdBasicAuth">
        <xsl:value-of select="local:getIdBasicAuth()"/>
      </xsl:element>
      
      <xsl:element name="getId">
        <xsl:value-of select="local:getId(.)"/>
      </xsl:element>
      <!--Details added for OnError.  The next four functions were added specifically for OnError.xsl
		These functions will return error messages. -->
	  <xsl:element name="examineX509">
        <xsl:value-of select="local:examineX509(.)"/>
      </xsl:element>
	
	  <xsl:element name="examineUsernameToken">
        <xsl:value-of select="local:examineUsernameToken(.)"/>
      </xsl:element>

	  <xsl:element name="examineBasicAuth">
        <xsl:value-of select="local:examineBasicAuth()"/>
      </xsl:element>
	  
	  <!--LDPAP connection parameters must be passed to this function for it to work.-->
      <xsl:element name="canLDAPbeReached">
        <xsl:value-of select="local:canLDAPbeReached(.)"/>
      </xsl:element>
      
       <!--Runs only if the authentication was a certificate.  This will pull the CN value only from the certificate information-->
	<xsl:if test="local:isIdX509(.)">
        <xsl:element name="CN">
          <xsl:value-of select="local:CNfromDN(local:getIdDN(.))"/>
        </xsl:element>
      </xsl:if>
      
    </xsl:element>
    
  </xsl:template>
  
  
  <!-- 
    Determine whether the request contains a binary security token with an X509 certificate.
    Returns boolean true or false (not string 'true' or 'false')
  -->
  <func:function name="local:isIdX509">
    <xsl:param name="request"/>
    <!--
      This xpath tests whether the request contains an X509 certificate in a binary security token.
      
      The first two terms (/*[local-name()='Envelope']/*[local-name()='Header']) are insensitive to
      whether the request is SOAP 1 or SOAP 1.2. 
      
      The wsse:Security term identifies the WS-Security header in the request (if one is present).
      
      The final term, wsse:BinarySecurityToken[@ValueType='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3'],
      identifies the type of a X509 certificate is present.

<func:result select="($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/ds:Signature/ds:KeyInfo/wsse:SecurityTokenReference/wsse:KeyIdentifier[@ValueType='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509SubjectKeyIdentifier'] !='')" />
</func:function>

    -->
 
 <func:result select="($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/wsse:BinarySecurityToken[@ValueType=$X509v3 or @ValueType=$X509PKIPathv1]) 
	or ($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/ds:Signature/ds:KeyInfo/wsse:SecurityTokenReference/wsse:KeyIdentifier[@ValueType='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509SubjectKeyIdentifier'])
	or ($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/ds:Signature/ds:KeyInfo/wsse:SecurityTokenReference/*[local-name()='X509Data'])
	or ($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/ds:Signature/ds:KeyInfo/wsse:SecurityTokenReference/wsse:KeyIdentifier[@ValueType=$X509v3])"/>
</func:function>
  
  <!-- 
    Determine whether the request contains a username token.
    Returns boolean true or false (not string 'true' or 'false')
  -->
  <func:function name="local:isIdUsernameToken">
    <xsl:param name="request"/>
    <!--
      This xpath tests whether the request contains a username token.
      
      The first two terms (/*[local-name()='Envelope']/*[local-name()='Header']) are insensitive to
      whether the request is SOAP 1 or SOAP 1.2. 
      
      The wsse:Security term identifies the WS-Security header in the request (if one is present).
      
      The final term, wsse:UsernameToken, identifies whether a UsernameToken is present.
    -->
    <func:result select="$request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/wsse:UsernameToken != ''"/>
  </func:function>
  
  
  
  <!-- 
    Determine whether the request contains a Basic Auth header.
    Returns boolean true or false (not string 'true' or 'false')
  -->
  <func:function name="local:isIdBasicAuth">
    <func:result select="starts-with(dp:request-header('Authorization'), 'Basic ')"/>
  </func:function>
  
  
  
  <!-- 
    Return the DN from the X509 certificate, or an empty string.
  -->
  <func:function name="local:getIdDN">
    <xsl:param name="request"/>
    <func:result>
      
      <!-- Pick out the X509 certificate. $request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/wsse:BinarySecurityToken[@ValueType=$X509v3 or @ValueType=$X509PKIPathv1]-->
      <!--<xsl:variable name="X509" select="string($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/wsse:BinarySecurityToken[@ValueType='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3'])"/>-->
      <xsl:variable name="X509" select="string($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/wsse:BinarySecurityToken[@ValueType=$X509v3 or @ValueType=$X509PKIPathv1])"/>
      
      <xsl:choose>
        <xsl:when test="$X509 != ''">
          
          <!-- Get the "subject" from the cert, which is usually a DN. -->
          <xsl:value-of select="dp:get-cert-subject(concat('cert:', $X509))"/>
          
        </xsl:when>
        <xsl:otherwise>
          
          <!-- No cert, no joy.  Return an empty string. -->
          <xsl:value-of select="''"/>
          
        </xsl:otherwise>
      </xsl:choose>
      
    </func:result>
  </func:function>
  
  
  <!-- 
    Return the user name from a WS-Security UsernameToken, or return an empty string.
  -->
  <func:function name="local:getIdUNT">
    <xsl:param name="request"/>
    <func:result select="string($request/*[local-name()='Envelope']/*[local-name()='Header']/wsse:Security/wsse:UsernameToken/wsse:Username)"/>
  </func:function>
  

  <!-- 
    Return the userid from the Basic Auth HTTP header, or return an empty string.
  -->
  <func:function name="local:getIdBasicAuth">
    <func:result>
      
      <xsl:variable name="hdr" select="dp:request-header('Authorization')"/>
      <xsl:choose>
        <xsl:when test="starts-with($hdr, 'Basic ')">
          
          <!--
            The Authorization header value is "Basic xxxxxx" where xxxxxx is a base-64 encoded string 
            of the form "uid:pwd".  So this line of code peels off the xxxxx part, decodes it, then picks
            off the userid.
          -->
          <xsl:value-of select="substring-before(dp:decode(substring-after($hdr, 'Basic '), 'base-64'), ':')"/>
          
        </xsl:when>
        <xsl:otherwise>
          
          <!-- No Basic Auth header so no joy.  Return an empty string. -->
          <xsl:value-of select="''"/>
          
        </xsl:otherwise>
      </xsl:choose>
      
    </func:result>
  </func:function>
  
  
  
  <!-- 
    Returns the userid or DN provided in a basic auth header, a username token, or an X509 certificate (in that order). 
  -->
  <func:function name="local:getId">
    <xsl:param name="request"/>
    <func:result>
      <xsl:choose>
        <xsl:when test="local:isIdBasicAuth()">
          <xsl:value-of select="local:getIdBasicAuth()"/>
        </xsl:when>
        <xsl:when test="local:isIdUsernameToken($request)">
          <xsl:value-of select="local:getIdUNT($request)"/>
        </xsl:when>
        <xsl:when test="local:isIdX509($request)">
				<xsl:choose>
						<xsl:when test="local:getIdDN($request)=''">
						       <xsl:value-of select="'OTHER_X509_Value'"/>
						</xsl:when>  
						<xsl:otherwise>
						<xsl:value-of select="local:getIdDN($request)"/>
						</xsl:otherwise>
				</xsl:choose>	
        </xsl:when>
        <xsl:otherwise> 
          <xsl:value-of select="''"/>
        </xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>
  
  
  <!-- 
    Return the CN contained in a DN, assuming that there IS a CN in the DN.
  -->
  <func:function name="local:CNfromDN">
    <xsl:param name="DN"/>
    <func:result>
      <!--
        It might seem simpler to just search for CN=, but this may be part of the content of a field,
        so we check more carefully, including comma in the search because comma is reserved solely
        for separating DN values.
      -->
      <xsl:variable name="afterCN">
        <xsl:choose>
          <xsl:when test="starts-with($DN, 'CN=')">
            <!-- CN is the first thing in the DN. -->
            <xsl:value-of select="substring-after($DN, 'CN=')"/>
          </xsl:when>
          <xsl:when test="starts-with($DN, ', CN=')">
            <!-- CN is not the first thing in the DN, and there are blanks following the commas -->
            <xsl:value-of select="substring-after($DN, ', CN=')"/>
          </xsl:when>
          <xsl:when test="starts-with($DN, ',CN=')">
            <!-- CN is not the first thing in the DN, and there are no blanks following the commas -->
            <xsl:value-of select="substring-after($DN, ',CN=')"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- No CN in the DN. -->
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <!-- Peel off the CN value, unless it is empty or the CN term is the last one in the DN. -->
      <xsl:choose>
        <xsl:when test="contains($afterCN, ',')">
          <xsl:value-of select="substring-before($afterCN, ',')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$afterCN"/> <!-- either CN wasn't present, or it was the final/only term in the DN. -->
        </xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>
  
    <!-- 
    Return the OU contained in a DN, assuming that there IS an OU in the DN.
  -->
  <func:function name="local:OUfromDN">
    <xsl:param name="DN"/>
    <func:result>
      <!--
        It might seem simpler to just search for OU=, but this may be part of the content of a field,
        so we check more carefully, including comma in the search because comma is reserved solely
        for separating DN values.
      -->
      <xsl:variable name="afterOU">
        <xsl:choose>
          <xsl:when test="contains($DN, 'OU=')">
            <!--OU iscontained in the DN. -->
            <xsl:value-of select="substring-after($DN, 'OU=')"/>
            <xsl:message>#####OU exist and is: <xsl:value-of select="$DN"/>  </xsl:message> 
          </xsl:when>
          <xsl:otherwise>
            <!-- No OU in the DN. -->
            <xsl:message>#####NO OU exist and is: <xsl:value-of select="$DN"/>  </xsl:message>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <xsl:message>#####afterOU exist and is: <xsl:value-of select="$afterOU"/>  </xsl:message>

      <!-- Peel off the OU value, unless it is empty or the OU term is the last one in the DN. -->
      <xsl:choose>
        <xsl:when test="contains($afterOU, ',')">
          <xsl:value-of select="substring-before($afterOU, ',')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$afterOU"/> <!-- either OU wasn't present, or it was the final/only term in the DN. -->
        </xsl:otherwise>
      </xsl:choose>
    </func:result>
  </func:function>
  <!-- NEW FUNCTIONS **********************************************************************************************************-->
  <!-- 
    Examine the supplied <wsse:Security> element which is guaranteed to contain a <wsse:BinarySecurityToken> 
    element containing an X509 certificate. Return a string indicating what the problem might be.
  -->
     <!--<xsl:variable name="ErrLogCat" select="'AMXErrCat'"/>
     <xsl:variable name="dnVal" select="local:getIdDN(.)"/>
     <xsl:variable name="cnVal" select="local:CNfromDN($dnVal)"/>
     <xsl:variable name="baVal" select="local:getIdBasicAuth()"/>
     <xsl:variable name="operationName" select="dp:variable('var://context/ActiveMatrixESB/operation')"/>
     <xsl:variable name="svcName" select = "dp:variable('var://context/ActiveMatrixESB/serviceName')"/>
     <xsl:variable name="userID" select = "dp:variable('var://context/WSM/identity/username')"/>
     <xsl:variable name="soapAct" select = "dp:http-request-header('SOAPAction')"/>
     <xsl:variable name="reqBody" select="dp:variable('var://context/copyOfInput/_roottree')/soap:Envelope/soap:Body" />-->
  
  <func:function name="local:examineX509">
    <xsl:param name="wssec"/>
    <func:result>
      <!--MAKE SURE VALIDATION CREDENTIAL IS POPULATED AND ACCURATE FOR THIS SECTION TO WORK-->
      <xsl:choose>
        <xsl:when test="not($wssec/dsig:Signature)">
          
          <!-- The <wsse:Security> element doesn't contain a signature! But it was cons -->
          <xsl:variable name="errorMessage" select="concat('The name(',$wssec,') element lacks a signature.  An XML digital signature required.')"/>
		  <dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />   
           <xsl:variable name="supportMessage" select="concat('***No signature was included in the WS-Security section of the message.(TID:',$transactionId,')')"/>
          <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />


        </xsl:when>
        <xsl:otherwise>
          
          <!-- 
            A digital signature is present, but whether it is signed correctly is difficult to verify.
            Examine the certificate instead, which is much easier. ;)
          -->
         
          <!-- Extract the raw base-64 encoded certificate (it is the text content of the <wsse:BinarySecurityToken>). @ValueType=$X509v3 or @ValueType=$X509PKIPathv1-->
         <!-- <xsl:variable name="cert" select="string($wssec/wsse:BinarySecurityToken[@ValueType='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3'])"/>-->
          <xsl:variable name="cert" select="string($wssec/wsse:BinarySecurityToken[@ValueType=$X509v3 or @ValueType=$X509PKIPathv1])"/>
          <!-- Use dp:validate-certificate() to examine the cert, including checking it against a "well known" valcred. -->
          <xsl:variable name="certnode">
            <input>
              <subject>
                <!-- Cert is used for only one certificate; pkipath is used if there is a chain of certs being used in the message-->
                <!-- This test allows for someone to pass either a full list of pki certs or a single cert in the cert value of the SOAP message-->
                <!--<xsl:value-of select="concat('cert:',$cert)"/>-->
                <xsl:choose>
                <xsl:when test="$X509v3 != ''">
                <xsl:value-of select="concat('cert:',$cert)"/>
                </xsl:when>
                <xsl:otherwise>
                <xsl:value-of select="concat('pkipath:',$cert)"/>
                </xsl:otherwise>
                </xsl:choose>
              </subject>
            </input>
          </xsl:variable>
          <xsl:variable name="validationResult" select="dp:validate-certificate($certnode, $valcred) "/>
          
          <!-- Return dp:validate-certificate()'s complaint. -->
          <xsl:value-of select="'Authentication Failure: '"/>
          <xsl:choose>
            <xsl:when test="$validationResult = '*ASN.1 parse of certificate failed*'">
              <xsl:variable name="errorMessage" select="'Your x509 digital certficate is invalid. It has been corrupted or otherwise compromised.'"/>
			  <dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
              <xsl:variable name="supportMessage" select="concat('***Certificate failed validation because it was not in the correct format from the client or may have been truncated by another system.(TID:',$transactionId,')')"/>
			  <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" /> 
            </xsl:when>
			<xsl:when test="$validationResult = 'certificate not trusted'">
               <xsl:variable name="errorMessage" select="'One of the signatures on the request document was signed by an unknown or untrusted party. The signature cannot be trusted.'"/>
				<dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />		      
				<xsl:variable name="supportMessage" select="concat('***Certificate is not included in Valcred:', $valcred,'.', ' Add certificate to Valcred to resolve error.(TID:',$transactionId,')')"/>
                 <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />   
            </xsl:when>
			<xsl:when test="$validationResult = 'certificate has expired'">
               <xsl:variable name="errorMessage" select="'Your x509 certficate has expired.'"/>
			   <dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
		    <xsl:variable name="supportMessage" select="concat('***Certificate has expired. Add new certificate to Valcred in Datapower to allow access.(TID:',$transactionId,')')"/>
		      <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" /> 
            </xsl:when>
			<xsl:when test="$validationResult != ''">
              <xsl:variable name="errorMessage" select="$validationResult"/>
			  <dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
              <xsl:variable name="supportMessage" select="concat('***Certificate validation did not fail with a known message.  Add this message to the utility functions to increase details:',$validationResult,'(TID:',$transactionId,')')"/>
              <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
            </xsl:when>
            <xsl:otherwise>

              <!-- The certificate itself is fine so the only remaining possibility is an incorrect signature. -->
              <xsl:variable name="errorMessage" select="'The digitial signature in the message is invalid.  Either the message was changed after it was signed or tampered with in transit.'"/>
			  <dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />           
			  <xsl:variable name="supportMessage" select="concat('***Certificate signature was tampered with because the certificate portion was validated successfully.(TID:',$transactionId,')')"/>
              <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
            </xsl:otherwise>
          </xsl:choose>
          
        </xsl:otherwise>
      </xsl:choose>
      
    </func:result>
  </func:function>
  
  
  
  <!-- 
    Examine the supplied <wsse:Security> element which is guaranteed to contain a <wsse:UsernameToken> element. 
  -->
  <func:function name="local:examineUsernameToken">
    <xsl:param name="wssec"/>
    <func:result>
       
      <xsl:choose>
        <xsl:when test="$wssec/wsse:UsernameToken/wsse:Username != '' and $wssec/wsse:UsernameToken/wsse:Password != ''">
			<xsl:variable name="LDAPReachability">
			<xsl:value-of select="local:canLDAPbeReached()"/>
			</xsl:variable>
          <!-- We can infer that the problem is a bad uid/password combination. -->
				<xsl:choose>
				<xsl:when test="$LDAPReachability != ''">
					<xsl:variable name="errorMessage" select="concat('Error in Authentication.  The LDAP server is not available for more details.  ',$LDAPReachability,'. ')"/>
					<dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />  
					<xsl:variable name="supportMessage" select="concat('***The Username/Password were found in the WS-Security Header in the message and an LDAP connection was attempted to determine more details.  Additional details could not be verified.  This may be a misconfiguration on Datapower with the error processing, or the LDAP could be unreachable.',$LDAPReachability,'(TID:',$transactionId,')')"/>
              		<dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />		
				</xsl:when>
				<xsl:otherwise>
					<xsl:variable name="errorMessage" select="concat('The userid/password is invalid.')" />
					<dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
					<xsl:variable name="supportMessage" select="concat('***The Username/Password in the WS-Security Header was found and LDAP was contacted. The client is most likely not sending a correct combination.',$LDAPReachability,'(TID:',$transactionId,')')"/>
              		<dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />		
				</xsl:otherwise>
                </xsl:choose>
        </xsl:when>



        <xsl:when test="$wssec/wsse:UsernameToken/wsse:Username != '' and $wssec/wsse:UsernameToken/wsse:Password = ''">
          
          <xsl:variable name="errorMessage" select="concat('You did not supply a password to go with the userid: ', $wssec/wsse:UsernameToken/wsse:Username)"/>
          <dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
		  <xsl:variable name="supportMessage" select="concat('***The Password was either not provided or it was not found in the correct location.  This client should correct the message.  This indicates the username was present but specifically no password was available.(TID:',$transactionId,')')"/>
          <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
        </xsl:when>
        <xsl:otherwise>
          
          <xsl:variable name="errorMessage" select="concat('The WS-Security Username Token was incomplete and/or malformed causing either a userid or password not to be found.')"/>
           <dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
		   <xsl:variable name="supportMessage" select="concat('***Username/Password was either not provided or it was not found in the correct location.  This client should correct the message.(TID:',$transactionId,')')"/>
           <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
        </xsl:otherwise>
      </xsl:choose>
      
    </func:result>
  </func:function>
  
  
  
  <!-- 
    Examine the current Basic Auth header (which is guaranteed to exist) and see if you can explain an
    AU/AZ failure.
  -->
  <func:function name="local:examineBasicAuth">
    <func:result>

      <xsl:variable name="authHeader" select="dp:request-header('Authorization')"/>
      <xsl:variable name="uidpwd" select="dp:decode(substring-after($authHeader, 'Basic '), 'base-64')"/>
      <xsl:variable name="uid" select="substring-before($uidpwd, ':')"/>
      <xsl:variable name="pwd" select="substring-after($uidpwd, ':')"/>
      
      <xsl:choose>
        <xsl:when test="$uid != '' and $pwd != ''">
			<xsl:variable name="LDAPReachability">
			<xsl:value-of select="local:canLDAPbeReached()"/>
			</xsl:variable>
          <!-- We can infer that the problem is a bad uid/password combination. -->
				<xsl:choose>
				<xsl:when test="$LDAPReachability != ''">
				<xsl:variable name="errorMessage" select="concat('Error in Authentication.  The LDAP server can not be reached currently for more details. ',$LDAPReachability,'. ')"/>
				<dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
				<xsl:variable name="supportMessage" select="concat('***The Username/Password in the BASIC Authentication was found but LDAP could not be reached for further details.  Additional details could not be verified.  This may be a misconfiguration on Datapower with the error processing, or the LDAP could be unreachable.',$LDAPReachability,'(TID:',$transactionId,')')"/>
			    <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
				</xsl:when>

				<xsl:otherwise>
					<!--<xsl:value-of select="local:canLDAPbeReached(concat('The userid/password combination ', $uid, '/****** does not work.'))"/>-->
					<xsl:variable name="errorMessage" select="concat('The userid/password combination ', $uid, '/****** does not work.')" />
					<dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
					<xsl:variable name="supportMessage" select="concat('***The Username/Password in the BASIC Authentication was found and LDAP was contacted. The client is most likely not sending a correct combination.',$LDAPReachability,'(TID:',$transactionId,')')"/>
			        <dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
				</xsl:otherwise>
                </xsl:choose>
        </xsl:when>

        <xsl:when test="$uid != '' and $pwd = ''">
          <xsl:variable name="errorMessage" select="concat('Missing password for userid: ', $uid)"/>
			<dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
          	<xsl:variable name="supportMessage" select="concat('***Username/Password BASIC Authentication did not include a password value.  Client should correct the message.(TID:',$transactionId,')')"/>
			<dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
		</xsl:when>
        <xsl:otherwise>
          
          <xsl:variable name="errorMessage" select="concat('The Basic Auth header is missing a userid or password.')"/>
			<dp:set-variable name="'var://context/errorInfo/errorMessage'" value="$errorMessage" />
           <xsl:variable name="supportMessage" select="concat('***Username/Password BASIC Authentication was either not provided or it was not found in the correct location.  Client should correct the message.(TID:',$transactionId,')')"/>
			<dp:set-variable name="'var://context/errorInfo/supportMessage'" value="$supportMessage" />
        </xsl:otherwise>
      </xsl:choose>
      
    </func:result>
  </func:function>
  
  
  <!-- 
    Attempt to simply reach LDAP.  If it can be reached then the userid/password is bad, otherwise
    AAA failed to authorize the userid/password because LDAP was unreachable.  Returns an error
    message that reflects one possibility or the other.
  -->
  <func:function name="local:canLDAPbeReached">
    <xsl:param name="defaultMsg"/>
    <func:result>
           
      <xsl:choose>
        <xsl:when test="$ldapHostname != ''">
          
          <!-- LDAP is configured, so see if it can be reached. -->
          <xsl:variable name="testldap" select="dp:ldap-search($ldapHostname, $ldapPort, $ldapId, $ldapPwd, 'DC=delta, DC=rl, DC=delta, DC=com', 'dn', '(&amp;(objectClass=user)(dalLoginList=svcdpw))', 'sub', '', '', 'v3')"/>
            <xsl:choose>
            <xsl:when test="$testldap//error">
              <xsl:value-of select="'Cannot connect to LDAP to authenticate the userid/password'"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$defaultMsg" />
            </xsl:otherwise>
          </xsl:choose>
          
        </xsl:when>
        <xsl:otherwise>
          
          <!-- LDAP isn't important, so just return the default message. -->
          <xsl:value-of select="$defaultMsg"/>
          
        </xsl:otherwise>
      </xsl:choose>
      
    </func:result>
  </func:function>
</xsl:stylesheet>