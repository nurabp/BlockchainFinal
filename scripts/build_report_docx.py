from __future__ import annotations

import datetime as dt
import html
import shutil
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
ASSETS = DOCS / "presentation_assets"
OUT = DOCS / "RWA_Governed_Protocol_Final_Report.docx"

NS_W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS_R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"
NS_WP = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
NS_PIC = "http://schemas.openxmlformats.org/drawingml/2006/picture"

EMU_PER_INCH = 914400


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def xml_text(text: str) -> str:
    return escape(text)


def p(text: str = "", style: str | None = None, bold: bool = False, italic: bool = False) -> str:
    style_xml = f'<w:pPr><w:pStyle w:val="{style}"/></w:pPr>' if style else ""
    rpr = []
    if bold:
        rpr.append("<w:b/>")
    if italic:
        rpr.append("<w:i/>")
    rpr_xml = f"<w:rPr>{''.join(rpr)}</w:rPr>" if rpr else ""
    if not text:
        return f"<w:p>{style_xml}</w:p>"
    lines = text.split("\n")
    runs = []
    for i, line in enumerate(lines):
        if i:
            runs.append("<w:br/>")
        runs.append(f"<w:t xml:space=\"preserve\">{xml_text(line)}</w:t>")
    return f"<w:p>{style_xml}<w:r>{rpr_xml}{''.join(runs)}</w:r></w:p>"


def heading(text: str, level: int) -> str:
    return p(text, f"Heading{level}")


def bullet(text: str) -> str:
    return p("- " + text, "Bullet")


def page_break() -> str:
    return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'


def table(rows: list[list[str]], widths: list[int] | None = None) -> str:
    if not rows:
        return ""
    widths = widths or [2500] * len(rows[0])
    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    out = [
        '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblLook w:firstRow="1" w:noHBand="0" w:noVBand="1"/></w:tblPr>'
        f"<w:tblGrid>{grid}</w:tblGrid>"
    ]
    for r_idx, row in enumerate(rows):
        out.append("<w:tr>")
        for cell in row:
            shade = '<w:shd w:fill="D9EAD3"/>' if r_idx == 0 else ""
            out.append(
                "<w:tc><w:tcPr>"
                f'<w:tcW w:w="{widths[min(len(widths)-1, row.index(cell))]}" w:type="dxa"/>{shade}'
                "</w:tcPr>"
                f"{p(cell, bold=(r_idx == 0))}"
                "</w:tc>"
            )
        out.append("</w:tr>")
    out.append("</w:tbl>")
    return "".join(out)


def code_block(text: str) -> str:
    lines = [line.rstrip() for line in text.strip().splitlines()]
    body = "\n".join(lines)
    return (
        '<w:p><w:pPr><w:pStyle w:val="CodeBlock"/></w:pPr>'
        f'<w:r><w:t xml:space="preserve">{xml_text(body)}</w:t></w:r></w:p>'
    )


def image_xml(rid: str, name: str, path: Path, width_in: float = 6.4) -> str:
    with Image.open(path) as img:
        width_px, height_px = img.size
    cx = int(width_in * EMU_PER_INCH)
    cy = int(cx * height_px / width_px)
    doc_id = "".join(ch for ch in rid if ch.isdigit()) or "1"
    return f"""
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:drawing>
          <wp:inline distT="0" distB="0" distL="0" distR="0">
            <wp:extent cx="{cx}" cy="{cy}"/>
            <wp:effectExtent l="0" t="0" r="0" b="0"/>
            <wp:docPr id="{doc_id}" name="{xml_text(name)}"/>
            <wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="{NS_A}" noChangeAspect="1"/></wp:cNvGraphicFramePr>
            <a:graphic xmlns:a="{NS_A}">
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic xmlns:pic="{NS_PIC}">
                  <pic:nvPicPr><pic:cNvPr id="0" name="{xml_text(path.name)}"/><pic:cNvPicPr/></pic:nvPicPr>
                  <pic:blipFill><a:blip r:embed="{rid}" xmlns:r="{NS_R}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                  <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>
    """


def caption(text: str) -> str:
    return p(text, "Caption", italic=True)


def styles_xml() -> str:
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="{NS_W}">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr>
    <w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:rPr><w:b/><w:sz w:val="40"/><w:color w:val="17365D"/></w:rPr>
    <w:pPr><w:jc w:val="center"/><w:spacing w:after="240"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Subtitle">
    <w:name w:val="Subtitle"/>
    <w:rPr><w:sz w:val="26"/><w:color w:val="444444"/></w:rPr>
    <w:pPr><w:jc w:val="center"/><w:spacing w:after="240"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>
    <w:rPr><w:b/><w:sz w:val="30"/><w:color w:val="17365D"/></w:rPr>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/>
    <w:rPr><w:b/><w:sz w:val="25"/><w:color w:val="274E13"/></w:rPr>
    <w:pPr><w:spacing w:before="180" w:after="100"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Bullet">
    <w:name w:val="Bullet"/><w:basedOn w:val="Normal"/>
    <w:pPr><w:ind w:left="360" w:hanging="180"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Caption">
    <w:name w:val="Caption"/><w:basedOn w:val="Normal"/>
    <w:rPr><w:i/><w:sz w:val="18"/><w:color w:val="666666"/></w:rPr>
    <w:pPr><w:jc w:val="center"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="CodeBlock">
    <w:name w:val="CodeBlock"/><w:basedOn w:val="Normal"/>
    <w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="18"/></w:rPr>
    <w:pPr><w:shd w:fill="F3F6F4"/><w:spacing w:before="80" w:after="80"/></w:pPr>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr><w:tblBorders>
      <w:top w:val="single" w:sz="4" w:color="999999"/>
      <w:left w:val="single" w:sz="4" w:color="999999"/>
      <w:bottom w:val="single" w:sz="4" w:color="999999"/>
      <w:right w:val="single" w:sz="4" w:color="999999"/>
      <w:insideH w:val="single" w:sz="4" w:color="999999"/>
      <w:insideV w:val="single" w:sz="4" w:color="999999"/>
    </w:tblBorders></w:tblPr>
  </w:style>
</w:styles>"""


def document_xml(images: dict[str, tuple[str, Path]]) -> str:
    body: list[str] = []

    body.append(p("RWA Governed Protocol", "Title"))
    body.append(p("Final Project Report: Asset-Backed Tokenization, Vault Yield, AMM Liquidity, and On-Chain Governance", "Subtitle"))
    body.append(p("Akhmetov Nurali SE2404", bold=True))
    body.append(p("Blockchain Technologies 2", bold=True))
    body.append(p(f"Generated: {dt.date.today().isoformat()}"))
    body.append(p("Repository: C:\\Users\\NurKids\\Desktop\\finalblockchain"))
    body.append(page_break())

    body.append(heading("Abstract", 1))
    body.append(p(
        "This report presents the RWA Governed Protocol, a full-stack blockchain final project built with Solidity, Foundry, React, ethers.js, and The Graph-compatible indexing. "
        "The system implements an asset-backed governance token, an ERC4626-style vault, a constant-product AMM, a Chainlink-style oracle adapter, proposal voting with timelock execution, a UUPS-style issuer upgrade path, and a classroom-ready frontend demo. "
        "The project was validated with deterministic Foundry tests, fuzz tests, invariant tests, frontend production build checks, static analysis evidence, deployment documentation, and screenshots from the working dApp."
    ))

    body.append(heading("1. Introduction", 1))
    body.append(p(
        "The selected final project direction is an RWA tokenization platform. The goal is to demonstrate how a decentralized protocol can represent off-chain collateral on-chain, route that token through DeFi primitives, and place system changes under transparent governance. "
        "The implementation is intentionally broad: it combines token standards, upgradeability, oracle integration, AMM mechanics, vault accounting, event indexing, and a usable frontend."
    ))
    body.append(p(
        "From the user perspective, the application supports connecting MetaMask, checking wallet RWA balance, delegating voting power, depositing into a vault, interacting with AMM liquidity, and voting on proposals. "
        "From the evaluator perspective, the repository includes source contracts, tests, documentation, screenshots, deployment scripts, and a reproducible local Anvil demo path."
    ))

    body.append(heading("2. Development Environment and Tools", 1))
    for item in [
        "Solidity and Foundry were used for contract development, compilation, unit testing, fuzz testing, invariant testing, coverage, and deployment scripting.",
        "React, Vite, and ethers.js were used for the frontend dApp and wallet transaction flow.",
        "The Graph subgraph schema and mappings were prepared for protocol event indexing.",
        "Slither was used as the static analysis tool for security-oriented checks.",
        "Local Anvil chain 31337 is used for a clean classroom demo when external L2 faucets are unavailable.",
        "The L2 deployment path is parameterized for Arbitrum Sepolia, Base Sepolia, Optimism Sepolia, and zkSync Sepolia."
    ]:
        body.append(bullet(item))

    body.append(heading("3. Requirement Coverage Matrix", 1))
    body.append(table([
        ["Rubric requirement", "Implementation", "Evidence"],
        ["Advanced Solidity", "UUPS proxy path, CREATE/CREATE2 factory, inline Yul utility", "src/upgrade, src/factory, src/utils/YulMath.sol"],
        ["Token standards", "GovernanceToken, AssetBadgeNFT, RwaVault shares", "src/token, src/vault"],
        ["DeFi primitive", "Constant-product AMM with LP shares, 0.3% fee, slippage checks", "src/amm/ConstantProductAMM.sol"],
        ["Oracle", "Chainlink-style adapter with stale and invalid price rejection", "src/oracle/ChainlinkOracleAdapter.sol"],
        ["Governance", "Delegate, propose, vote, queue, execute through Governor and Timelock", "src/governance"],
        ["Subgraph", "Schema and mappings for deposits, swaps, proposals, and votes", "subgraph/schema.graphql, subgraph/src/mapping.ts"],
        ["Frontend", "Wallet connection, live reads, write transactions, local demo automation", "frontend/src/App.jsx"],
        ["Testing", "101 deterministic passing tests plus fork test implementation", "test/ProtocolTest.t.sol, test/RequirementMatrixTest.t.sol, test/ForkIntegrationTest.t.sol"],
        ["Security", "Slither high/medium clean evidence and manual audit report", "docs/audit-report.md"],
        ["Deployment", "Local Anvil broadcast and L2-ready runbook", "docs/deployment-addresses.md, docs/deployment-runbook.md"],
    ], [2450, 3650, 3450]))

    body.append(heading("4. System Architecture", 1))
    body.append(p(
        "The protocol is structured around a central RWA governance token. The token can be deposited into a vault, traded through an AMM, and used as voting power in governance. "
        "The oracle adapter reads external price data and rejects stale or invalid answers. The governor and timelock control privileged protocol actions after a delay."
    ))
    body.append(image_xml(images["architecture"][0], "Architecture diagram", images["architecture"][1], 6.5))
    body.append(caption("Figure 1. Protocol architecture: frontend, contracts, oracle, governance, and subgraph."))

    body.append(heading("5. Smart Contract Modules", 1))
    body.append(heading("5.1 GovernanceToken and Asset Issuance", 2))
    body.append(p(
        "GovernanceToken is the main RWA token. It supports balances, allowances, delegation, voting power, permit-style approval logic, and role-gated issuance. "
        "The issuer role is designed for accounts or issuer proxy contracts that represent off-chain collateral verification."
    ))
    body.append(heading("5.2 AssetBadgeNFT", 2))
    body.append(p(
        "AssetBadgeNFT provides an NFT-style proof badge for collateral or issuer metadata. This satisfies the non-fungible token requirement and gives the protocol a place to attach asset proof references."
    ))
    body.append(heading("5.3 RwaVault", 2))
    body.append(p(
        "RwaVault is an ERC4626-style vault. Users approve the vault, deposit RWA assets, and receive vault shares. The vault exposes totalAssets, convertToShares, convertToAssets, deposit, and withdraw flows."
    ))
    body.append(heading("5.4 ConstantProductAMM", 2))
    body.append(p(
        "The AMM implements the educational Uniswap V2-style invariant x*y=k. Liquidity providers deposit two assets and receive LP shares. Traders swap one asset for another with a 0.3% fee and minimum-output slippage protection."
    ))
    body.append(heading("5.5 Upgradeability and Factory", 2))
    body.append(p(
        "RwaIssuerUpgradeable demonstrates a UUPS-style upgrade path through an ERC1967 proxy. ProtocolFactory demonstrates both standard CREATE deployment and deterministic CREATE2 proxy deployment."
    ))

    body.append(heading("6. Protocol User Flows", 1))
    body.append(table([
        ["Flow", "Steps", "Important protection"],
        ["Issue RWA", "Authorized issuer calls issue -> token mints backed balance -> event emitted", "ISSUER_ROLE and governance-managed issuer rotation"],
        ["Deposit vault", "User approves token -> vault deposit -> shares minted", "Zero deposit rejection and share accounting"],
        ["AMM swap", "Trader approves token -> swap computes output -> reserves sync", "Slippage check, nonReentrant, reserve invariant"],
        ["Governance vote", "User delegates -> proposal created -> vote for/against -> counters update", "Proposal threshold, quorum, ALREADY_VOTED protection"],
        ["Timelock execution", "Succeeded proposal queued -> delay passes -> execution called", "Operation hash and delay gate"],
    ], [1800, 4700, 3050]))

    body.append(heading("7. Frontend dApp Evidence", 1))
    body.append(p(
        "The frontend is a React/Vite dashboard designed as an institutional DeFi control panel. It connects to MetaMask, detects the active chain, reads contract state, and sends real wallet transactions for delegate, deposit, swap, and vote actions."
    ))
    body.append(image_xml(images["frontend_overview"][0], "Frontend overview", images["frontend_overview"][1], 6.5))
    body.append(caption("Figure 2. Main frontend dashboard with wallet, protocol metrics, vault panel, and AMM panel."))
    body.append(image_xml(images["frontend_governance"][0], "Frontend governance", images["frontend_governance"][1], 6.5))
    body.append(caption("Figure 3. Governance and security section with proposal voting counters and assignment readiness evidence."))
    body.append(p(
        "For demonstration reliability, local chain 31337 includes helper logic: Proposal ID 0 creates the next proposal automatically, and Proposal ID 1, 2, 3, etc. can create missing local proposals before voting. "
        "This makes the demo repeatable without changing accounts, while still preserving the real smart contract rule that one wallet can vote only once per proposal."
    ))

    body.append(heading("8. Testing Evidence", 1))
    body.append(p(
        "The deterministic local test suite currently passes with 101 tests and 0 failures when excluding external fork RPC tests. The repository also contains fork integration tests for mainnet USDC, Uniswap V2, and Chainlink ETH/USD. "
        "The fork tests are separated because they depend on live RPC availability."
    ))
    body.append(image_xml(images["tests"][0], "Foundry test evidence", images["tests"][1], 6.5))
    body.append(caption("Figure 4. Foundry deterministic test evidence: 101 passing tests, 0 failures."))
    body.append(table([
        ["Test type", "Purpose", "Examples"],
        ["Unit tests", "Verify expected behavior for known cases", "mint, transfer, vault deposit, AMM swap, oracle reads"],
        ["Fuzz tests", "Explore many randomized inputs", "transfer amount, AMM liquidity amount, vault conversion"],
        ["Invariant tests", "Verify state properties after many calls", "supply, vault assets, AMM reserves, oracle configuration"],
        ["Fork tests", "Validate integrations against live mainnet contracts", "USDC, Uniswap V2 router, Chainlink ETH/USD"],
    ], [1900, 3300, 4350]))

    body.append(heading("9. Security Review", 1))
    body.append(p(
        "The project includes a dedicated audit report and security evidence. Static analysis was run with Slither high/medium filters and reports 0 high or medium findings. "
        "The code also includes vulnerability case studies to show understanding of reentrancy and access control failures, followed by fixed versions."
    ))
    body.append(image_xml(images["security"][0], "Security evidence", images["security"][1], 6.5))
    body.append(caption("Figure 5. Security evidence: Slither high/medium clean result and coverage summary."))
    for item in [
        "RwaVault and ConstantProductAMM use nonReentrant guards around value-moving logic.",
        "Privileged minting and issuer administration are role-gated.",
        "The Chainlink adapter rejects stale, zero, or negative prices.",
        "The timelock prevents immediate execution of governance-controlled actions.",
        "The audit report documents remaining operational risks and production recommendations."
    ]:
        body.append(bullet(item))

    body.append(heading("10. Subgraph and Indexed Data", 1))
    body.append(p(
        "The subgraph layer is prepared for The Graph indexing. It defines entities for tokens, vault deposits, swaps, proposals, and votes. The frontend can read from VITE_SUBGRAPH_URL when a hosted endpoint is configured, and it falls back to demo indexed activity for local presentation mode."
    ))
    body.append(code_block(
        """
query Proposals {
  proposals(first: 10) {
    id
    proposer
    description
    state
    forVotes
    againstVotes
  }
}
        """
    ))

    body.append(heading("11. Deployment Evidence", 1))
    body.append(p(
        "The deployment path is implemented through Foundry scripts. Local Anvil deployment is automated and deterministic for classroom presentation. The L2 deployment command is ready for Arbitrum Sepolia and similar L2 testnets. "
        "A real L2 broadcast was not completed in the current workspace because the prepared deployer wallet had 0 testnet ETH; therefore this report documents local deployment evidence and L2 dry-run status honestly."
    ))
    body.append(image_xml(images["deployment"][0], "Deployment evidence", images["deployment"][1], 6.5))
    body.append(caption("Figure 6. Deployment evidence: local Anvil deploy, deterministic addresses, and L2 dry-run status."))
    body.append(code_block(
        """
npm run local:demo

MetaMask network:
Network name: Local Anvil
RPC URL: http://127.0.0.1:8545
Chain ID: 31337
Currency: ETH
        """
    ))

    body.append(heading("12. Comparison With Course Criteria", 1))
    body.append(p(
        "The project is intentionally designed to cover the final assignment criteria as completely as possible. It includes advanced Solidity patterns, multiple token models, a DeFi primitive, oracle integration, governance, frontend transactions, testing evidence, security documentation, and deployment automation."
    ))
    body.append(table([
        ["Area", "Status", "Notes"],
        ["Advanced Solidity", "Implemented", "UUPS, CREATE2, Yul, access control, timelock state machine"],
        ["DeFi", "Implemented", "AMM, vault, LP shares, fees, slippage, reserves"],
        ["Oracle", "Implemented", "Chainlink-style feed adapter and stale checks"],
        ["Governance", "Implemented", "Delegate, propose, vote, queue, execute"],
        ["Frontend", "Implemented", "MetaMask, live reads, transactions, local demo UX"],
        ["Subgraph", "Prepared", "Schema and mappings ready; hosted URL configurable"],
        ["Testing", "Strong", "101 deterministic local tests plus fork test implementation"],
        ["Security", "Strong", "Slither high/medium clean and manual audit report"],
        ["L2 deploy/verify", "Partially blocked", "Dry-run and command ready; real verification needs faucet ETH"],
    ], [2200, 2000, 5350]))

    body.append(heading("13. Conclusion", 1))
    body.append(p(
        "The RWA Governed Protocol demonstrates a complete blockchain application rather than a single isolated contract. It combines tokenization, vault accounting, AMM liquidity, oracle safety checks, on-chain governance, event indexing, and a polished frontend interface. "
        "The local demo is reproducible with one command and the validation evidence shows that the deterministic test suite and frontend build pass successfully."
    ))
    body.append(p(
        "The main operational limitation is real L2 verification, which depends on obtaining testnet ETH. This does not block the technical deployment path: the runbook, scripts, addresses, and dry-run evidence are already prepared. "
        "For final presentation, the recommended demo is to run npm run local:demo, connect MetaMask to Local Anvil, show the dashboard, delegate voting power, deposit into the vault, and vote on a proposal."
    ))

    body.append(heading("14. Final Submission Checklist", 1))
    for item in [
        "Solidity source contracts included in src/.",
        "Foundry tests included in test/ with deterministic local passing evidence.",
        "Frontend dApp included in frontend/ and production build verified.",
        "Architecture document included in docs/architecture.md.",
        "Audit report included in docs/audit-report.md.",
        "Coverage and gas notes included in docs/coverage.md and docs/gas-report.md.",
        "Deployment runbook and local addresses included in docs/deployment-runbook.md and docs/deployment-addresses.md.",
        "Presentation included in docs/RWA_Governed_Protocol_Final_Presentation.pptx.",
        "Screenshots and evidence images included in docs/presentation_assets/.",
    ]:
        body.append(bullet(item))

    sect = """
      <w:sectPr>
        <w:pgSz w:w="11906" w:h="16838"/>
        <w:pgMar w:top="900" w:right="900" w:bottom="900" w:left="900" w:header="708" w:footer="708" w:gutter="0"/>
      </w:sectPr>
    """
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="{NS_W}" xmlns:r="{NS_R}" xmlns:wp="{NS_WP}" xmlns:a="{NS_A}">
  <w:body>
    {''.join(body)}
    {sect}
  </w:body>
</w:document>"""


def rels_xml(images: dict[str, tuple[str, Path]]) -> str:
    rels = [
        '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
        '<Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>',
    ]
    for key, (rid, path) in images.items():
        rels.append(
            f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/{path.name}"/>'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + "".join(rels)
        + "</Relationships>"
    )


def content_types_xml(images: dict[str, tuple[str, Path]]) -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>"""


def package_rels_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>"""


def core_xml() -> str:
    now = dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>RWA Governed Protocol Final Report</dc:title>
  <dc:creator>Akhmetov Nurali</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>"""


def app_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
 xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Word</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <Company>Blockchain Technologies 2</Company>
</Properties>"""


def settings_xml() -> str:
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="{NS_W}">
  <w:zoom w:percent="100"/>
  <w:defaultTabStop w:val="720"/>
</w:settings>"""


def main() -> None:
    required = {
        "architecture": ASSETS / "architecture-diagram.png",
        "frontend_overview": ASSETS / "frontend-overview.png",
        "frontend_governance": ASSETS / "frontend-governance.png",
        "tests": ASSETS / "tests-summary.png",
        "security": ASSETS / "security-summary.png",
        "deployment": ASSETS / "deployment-summary.png",
    }
    missing = [str(path) for path in required.values() if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing report assets: " + ", ".join(missing))

    images = {
        key: (f"rIdImage{i}", path)
        for i, (key, path) in enumerate(required.items(), start=1)
    }

    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", content_types_xml(images))
        z.writestr("_rels/.rels", package_rels_xml())
        z.writestr("docProps/core.xml", core_xml())
        z.writestr("docProps/app.xml", app_xml())
        z.writestr("word/document.xml", document_xml(images))
        z.writestr("word/styles.xml", styles_xml())
        z.writestr("word/settings.xml", settings_xml())
        z.writestr("word/_rels/document.xml.rels", rels_xml(images))
        for _key, (_rid, path) in images.items():
            z.write(path, f"word/media/{path.name}")

    print(OUT)


if __name__ == "__main__":
    main()
