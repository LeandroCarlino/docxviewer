"""Genera prueba-paginas.docx: 3 paginas A4, con saltos, colores y alineacion."""

import os
import zipfile

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "prueba-paginas.docx")

CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>"""

RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"""

DOC_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>"""

STYLES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults><w:rPrDefault><w:rPr>
    <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
    <w:sz w:val="22"/>
  </w:rPr></w:rPrDefault>
  <w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
</w:styles>"""


def run(text, bold=False, color=None, underline=False, highlight=None):
    rpr = ""
    if bold or color or underline or highlight:
        rpr = "<w:rPr>"
        if bold:
            rpr += "<w:b/>"
        if underline:
            rpr += '<w:u w:val="single"/>'
        if color:
            rpr += f'<w:color w:val="{color}"/>'
        if highlight:
            rpr += f'<w:highlight w:val="{highlight}"/>'
        rpr += "</w:rPr>"
    return f'<w:r>{rpr}<w:t xml:space="preserve">{text}</w:t></w:r>'


def p(children, align=None, size=None, before=None, after=None, indent=None):
    ppr = ""
    if align or size or before or after or indent:
        ppr = "<w:pPr>"
        if align:
            ppr += f'<w:jc w:val="{align}"/>'
        if size:
            ppr += f'<w:rPr><w:sz w:val="{size}"/></w:rPr>'
        if before or after:
            ppr += f'<w:spacing w:before="{before or 0}" w:after="{after or 0}"/>'
        if indent:
            ppr += f'<w:ind w:left="{indent}"/>'
        ppr += "</w:pPr>"
    if isinstance(children, str):
        children = [run(children)]
    return "<w:p>" + ppr + "".join(children) + "</w:p>"


def page_break():
    return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'


def rendered_break():
    return "<w:p><w:r><w:lastRenderedPageBreak/></w:r></w:p>"


PAGE1 = (
    p(
        [run("Informe de prueba", bold=True, color="1F5FA8")],
        align="center",
        size=44,
        after=240,
    )
    + p(
        "Este documento tiene tres paginas A4 con saltos explicitos, colores, alineacion y una tabla.",
        align="justify",
    )
    + p([run("Texto en rojo y negrita", bold=True, color="C00000")])
    + p([run("Subrayado y resaltado", underline=True, highlight="yellow")])
    + p("Izquierda")
    + p("Centrado", align="center")
    + p("Derecha", align="right")
    + page_break()
)

PAGE2 = (
    p([run("Pagina 2", bold=True, color="2E7D32")], size=36, after=200)
    + p(
        "El segundo salto se hace con la marca que escribe Word (lastRenderedPageBreak)."
    )
    + p("Primer parrafo de relleno. " * 6)
    + p("Segundo parrafo de relleno. " * 6)
    + rendered_break()
)

rows = [["Producto", "Unidades", "Precio"]]
for i in range(1, 9):
    rows.append([f"Articulo {i}", str(i * 2), f"{i * 1.5:.1f}"])

tbl = (
    '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
    "<w:tblBorders>"
    + "".join(
        f'<w:{s} w:val="single" w:sz="6" w:space="0" w:color="9AA5B1"/>'
        for s in ("top", "left", "bottom", "right", "insideH", "insideV")
    )
    + "</w:tblBorders></w:tblPr><w:tr>"
    + "".join(
        f'<w:tc><w:tcPr><w:shd w:val="clear" w:fill="DCE9F7"/></w:tcPr>'
        f"{p([run(c, bold=True)])}</w:tc>"
        for c in rows[0]
    )
    + "</w:tr>"
)
for r in rows[1:]:
    tbl += (
        "<w:tr>"
        + "".join(f"<w:tc><w:tcPr/>{p([run(c)])}</w:tc>" for c in r)
        + "</w:tr>"
    )
tbl += "</w:tbl>"

PAGE3 = (
    p([run("Pagina 3", bold=True, color="6A1B9A")], size=36, after=200)
    + p("Tabla con cabecera coloreada:")
    + tbl
)

DOCUMENT = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    "<w:document "
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    "<w:body>" + PAGE1 + PAGE2 + PAGE3 + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
    '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>'
    "</w:sectPr></w:body></w:document>"
)

with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", CONTENT_TYPES)
    z.writestr("_rels/.rels", RELS)
    z.writestr("word/document.xml", DOCUMENT)
    z.writestr("word/_rels/document.xml.rels", DOC_RELS)
    z.writestr("word/styles.xml", STYLES)

print(OUT, os.path.getsize(OUT), "bytes")
