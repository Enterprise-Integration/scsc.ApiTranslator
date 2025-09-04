<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  
  <!-- Sample XSLT for transforming a generic purchase order to partner-specific format -->
  <xsl:template match="/">
    <PartnerPurchaseOrder>
      <OrderHeader>
        <PONumber><xsl:value-of select="//orderId"/></PONumber>
        <PODate><xsl:value-of select="//orderDate"/></PODate>
        <PartnerCode>ACME_CORP</PartnerCode>
      </OrderHeader>
      <OrderDetails>
        <xsl:for-each select="//items/*">
          <LineItem>
            <ItemNumber><xsl:value-of select="position()"/></ItemNumber>
            <SKU><xsl:value-of select="sku"/></SKU>
            <Quantity><xsl:value-of select="quantity"/></Quantity>
            <UnitPrice><xsl:value-of select="unitPrice"/></UnitPrice>
            <ExtendedPrice><xsl:value-of select="quantity * unitPrice"/></ExtendedPrice>
          </LineItem>
        </xsl:for-each>
      </OrderDetails>
      <OrderSummary>
        <TotalItems><xsl:value-of select="count(//items/*)"/></TotalItems>
        <TotalAmount><xsl:value-of select="sum(//items/*/quantity * //items/*/unitPrice)"/></TotalAmount>
      </OrderSummary>
    </PartnerPurchaseOrder>
  </xsl:template>
</xsl:stylesheet>
