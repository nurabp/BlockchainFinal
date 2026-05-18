from __future__ import annotations

import html
import math
import os
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "docs" / "presentation_assets"
OUT = ROOT / "docs" / "RWA_Governed_Protocol_Final_Presentation.pptx"

SLIDE_W = 13_333_333
SLIDE_H = 7_500_000

BG = "07100E"
PANEL = "111A18"
PANEL2 = "16211F"
LINE = "243C34"
TEXT = "EDF7F2"
MUTED = "A8BAB2"
GREEN = "4CE3A0"
CYAN = "57C9D4"
AMBER = "E9B961"
RED = "EF786F"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt, max_width: int) -> list[str]:
    lines: list[str] = []
    for raw in text.split("\n"):
        words = raw.split()
        line = ""
        for word in words:
            test = f"{line} {word}".strip()
            if draw.textbbox((0, 0), test, font=fnt)[2] <= max_width or not line:
                line = test
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def terminal_image(path: Path, title: str, lines: list[str], width: int = 1500, height: int = 820) -> None:
    img = Image.new("RGB", (width, height), "#07100E")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((20, 20, width - 20, height - 20), radius=18, fill="#0D1714", outline="#24443A", width=2)
    d.ellipse((48, 48, 66, 66), fill="#EF786F")
    d.ellipse((78, 48, 96, 66), fill="#E9B961")
    d.ellipse((108, 48, 126, 66), fill="#4CE3A0")
    d.text((152, 43), title, fill="#EDF7F2", font=font(28, True))
    mono = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 25) if Path("C:/Windows/Fonts/consola.ttf").exists() else font(24)
    y = 104
    for line in lines:
        fill = "#4CE3A0" if line.startswith("[PASS]") or "0 result" in line or "passed" in line.lower() else "#C6D8D0"
        if "blocked" in line.lower() or "not broadcast" in line.lower():
            fill = "#E9B961"
        if line.startswith("$"):
            fill = "#57C9D4"
        for wrapped in wrap_text(d, line, mono, width - 110):
            d.text((54, y), wrapped, fill=fill, font=mono)
            y += 35
            if y > height - 55:
                break
        if y > height - 55:
            break
    img.save(path)


def architecture_image(path: Path) -> None:
    img = Image.new("RGB", (1600, 900), "#07100E")
    d = ImageDraw.Draw(img)
    title_f = font(38, True)
    node_f = font(26, True)
    small_f = font(20)
    d.text((60, 45), "RWA Governed Protocol Architecture", fill="#EDF7F2", font=title_f)

    nodes = {
        "Frontend dApp": (70, 170, 360, 280, "#16211F", "#57C9D4"),
        "GovernanceToken": (520, 140, 880, 250, "#16211F", "#4CE3A0"),
        "RwaVault": (520, 340, 880, 450, "#16211F", "#4CE3A0"),
        "AMM": (1010, 340, 1340, 450, "#16211F", "#E9B961"),
        "Governor": (520, 600, 880, 710, "#16211F", "#EF786F"),
        "Timelock": (1010, 600, 1340, 710, "#16211F", "#EF786F"),
        "Oracle Adapter": (1010, 140, 1340, 250, "#16211F", "#57C9D4"),
        "Subgraph": (70, 600, 360, 710, "#16211F", "#E9B961"),
    }
    for label, (x1, y1, x2, y2, fill, outline) in nodes.items():
        d.rounded_rectangle((x1, y1, x2, y2), radius=20, fill=fill, outline=outline, width=3)
        d.text((x1 + 24, y1 + 28), label, fill="#EDF7F2", font=node_f)

    arrows = [
        ((360, 225), (520, 195), "reads/writes"),
        ((360, 650), (520, 650), "proposal events"),
        ((700, 250), (700, 340), "deposit"),
        ((880, 395), (1010, 395), "liquidity"),
        ((880, 195), (1010, 195), "price feed"),
        ((700, 600), (700, 450), "votes"),
        ((880, 655), (1010, 655), "queue/execute"),
        ((1180, 600), (1180, 450), "admin control"),
    ]
    for (x1, y1), (x2, y2), label in arrows:
        d.line((x1, y1, x2, y2), fill="#7DE8BE", width=4)
        angle = math.atan2(y2 - y1, x2 - x1)
        ax, ay = x2, y2
        pts = [
            (ax, ay),
            (ax - 18 * math.cos(angle - 0.45), ay - 18 * math.sin(angle - 0.45)),
            (ax - 18 * math.cos(angle + 0.45), ay - 18 * math.sin(angle + 0.45)),
        ]
        d.polygon(pts, fill="#7DE8BE")
        d.text(((x1 + x2) // 2 - 45, (y1 + y2) // 2 - 30), label, fill="#A8BAB2", font=small_f)

    d.rounded_rectangle((70, 785, 1480, 850), radius=16, fill="#0D1714", outline="#24443A", width=2)
    d.text((100, 805), "External dependencies: MetaMask, Chainlink-style feed, The Graph mappings, L2 deployment path", fill="#C6D8D0", font=small_f)
    img.save(path)


def make_assets() -> dict[str, Path]:
    ASSETS.mkdir(parents=True, exist_ok=True)
    tests = ASSETS / "tests-summary.png"
    terminal_image(
        tests,
        "Foundry test evidence",
        [
            "$ forge test --summary --no-match-contract ForkIntegrationTest",
            "[PASS] ProtocolTest: 23 passed, 0 failed",
            "[PASS] RequirementMatrixTest: 78 passed, 0 failed",
            "[PASS] Invariants: supply, vault assets, AMM reserves, oracle config, admin role",
            "[PASS] Fuzz: transfer, approve, vault convert, oracle prices, Yul, AMM liquidity",
            "Deterministic local suite: 101 passed, 0 failed",
            "Fork suite configured: USDC, Uniswap V2 router, Chainlink ETH/USD",
            "Fork suite runs when a public Ethereum RPC is reachable",
        ],
    )
    security = ASSETS / "security-summary.png"
    terminal_image(
        security,
        "Security evidence",
        [
            "$ slither . --exclude-low --exclude-informational",
            "INFO:Slither:. analyzed (18 contracts with 63 detectors), 0 result(s) found",
            "$ forge coverage --report summary",
            "src/ production contracts: 346/360 lines ~= 96.11%",
            "Audit report covers CEI, ReentrancyGuard, privileged functions, oracle risk",
            "Case studies: reproduced + fixed reentrancy and access-control vulnerabilities",
        ],
    )
    deployment = ASSETS / "deployment-summary.png"
    terminal_image(
        deployment,
        "Local deployment evidence",
        [
            "$ npm run local:setup",
            "[PASS] Anvil chain 31337 reset for fresh demo",
            "[PASS] Deploy.s.sol broadcast completed",
            "[PASS] PostDeployCheck returned true",
            "Governor: 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
            "Token:    0x5FbDB2315678afecb367f032d93F642f64180aa3",
            "L2 dry-run estimated 13,596,611 gas on Arbitrum Sepolia",
            "Real L2 not broadcast: deployer had 0 testnet ETH",
        ],
    )
    arch = ASSETS / "architecture-diagram.png"
    architecture_image(arch)
    return {
        "tests": tests,
        "security": security,
        "deployment": deployment,
        "architecture": arch,
        "frontend_overview": ASSETS / "frontend-overview.png",
        "frontend_governance": ASSETS / "frontend-governance.png",
    }


def tx(x: float) -> int:
    return int(x * 914400)


def slide_bg() -> str:
    return (
        f'<p:bg><p:bgPr><a:solidFill><a:srgbClr val="{BG}"/></a:solidFill>'
        '<a:effectLst/></p:bgPr></p:bg>'
    )


def shape_text(
    x: float,
    y: float,
    w: float,
    h: float,
    text: str,
    size: int = 24,
    color: str = TEXT,
    bold: bool = False,
    fill: str | None = None,
    line: str | None = None,
    radius: bool = False,
    align: str = "l",
) -> str:
    shape_type = "roundRect" if radius else "rect"
    fill_xml = f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else '<a:noFill/>'
    line_xml = f'<a:ln w="12700"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill></a:ln>' if line else '<a:ln><a:noFill/></a:ln>'
    paragraphs = []
    for para in text.split("\n"):
        paragraphs.append(
            f'<a:p><a:pPr algn="{align}"/><a:r><a:rPr lang="en-US" sz="{size * 100}" '
            f'{"b=\"1\"" if bold else ""}><a:solidFill><a:srgbClr val="{color}"/></a:solidFill>'
            f'</a:rPr><a:t>{escape(para)}</a:t></a:r></a:p>'
        )
    return f"""
    <p:sp>
      <p:nvSpPr><p:cNvPr id="1" name="Text"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
      <p:spPr><a:xfrm><a:off x="{tx(x)}" y="{tx(y)}"/><a:ext cx="{tx(w)}" cy="{tx(h)}"/></a:xfrm>
      <a:prstGeom prst="{shape_type}"><a:avLst/></a:prstGeom>{fill_xml}{line_xml}</p:spPr>
      <p:txBody><a:bodyPr wrap="square" lIns="91440" tIns="45720" rIns="91440" bIns="45720"/><a:lstStyle/>
      {''.join(paragraphs)}</p:txBody>
    </p:sp>
    """


def title(text: str, subtitle: str | None = None) -> str:
    out = shape_text(0.65, 0.35, 11.8, 0.55, text, 30, TEXT, True)
    if subtitle:
        out += shape_text(0.68, 0.92, 11.2, 0.38, subtitle, 13, CYAN, True)
    return out


def bullet_box(x: float, y: float, w: float, h: float, heading: str, bullets: list[str], accent: str = GREEN) -> str:
    body = heading + "\n" + "\n".join(f"- {b}" for b in bullets)
    return shape_text(x, y, w, h, body, 16, TEXT, False, PANEL, LINE, True)


def image_xml(rid: int, x: float, y: float, w: float, h: float) -> str:
    return f"""
    <p:pic>
      <p:nvPicPr><p:cNvPr id="{100 + rid}" name="Picture {rid}"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>
      <p:blipFill><a:blip r:embed="rId{rid}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
      <p:spPr><a:xfrm><a:off x="{tx(x)}" y="{tx(y)}"/><a:ext cx="{tx(w)}" cy="{tx(h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>
    </p:pic>
    """


def slide_xml(content: str) -> str:
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>{slide_bg()}<p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    {content}
  </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>'''


def rels_xml(images: list[str]) -> str:
    rels = ['<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>']
    for idx, target in enumerate(images, start=2):
        rels.append(f'<Relationship Id="rId{idx}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/{target}"/>')
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + "".join(rels) + "</Relationships>"


class Slide:
    def __init__(self, xml: str, images: list[Path] | None = None):
        self.xml = xml
        self.images = images or []


def build_slides(assets: dict[str, Path]) -> list[Slide]:
    slides: list[Slide] = []
    slides.append(Slide(
        title("RWA Governed Protocol", "Full-stack decentralized protocol for asset-backed tokens, vault yield, AMM liquidity, and governance")
        + shape_text(0.7, 1.55, 5.4, 1.2, "Option C: RWA Tokenization Platform\nReact dApp + Foundry contracts + Subgraph + L2 deployment path", 22, TEXT, True)
        + bullet_box(0.7, 3.0, 5.4, 2.4, "Built for the course rubric", [
            "ERC20 governance token, ERC721 badge, ERC4626-style vault",
            "Custom AMM, Chainlink adapter, timelock governance",
            "Automated tests, Slither, coverage report, local demo deploy",
        ], CYAN)
        + image_xml(2, 6.55, 1.45, 5.95, 4.7),
        [assets["frontend_overview"]],
    ))
    slides.append(Slide(
        title("Rubric Coverage", "Mapping the implementation to the mandatory technical requirements")
        + bullet_box(0.65, 1.35, 3.9, 2.15, "Smart contracts", ["UUPS proxy path", "Factory CREATE + CREATE2", "Inline Yul benchmark", "ERC20 + ERC721 + vault"], GREEN)
        + bullet_box(4.75, 1.35, 3.9, 2.15, "Protocol modules", ["Custom x*y=k AMM", "Chainlink stale checks", "Governor + Timelock lifecycle", "Role-gated issuer"], CYAN)
        + bullet_box(8.85, 1.35, 3.8, 2.15, "Full stack", ["MetaMask dApp", "Subgraph mappings", "Testing and CI", "Docs, audit, gas report"], AMBER)
        + shape_text(0.85, 4.0, 11.6, 1.7, "Known submission caveat\nReal L2 verification is documented as ready but not broadcast because the deployer had 0 Arbitrum Sepolia ETH. Local Anvil deployment and post-deploy checks prove the reproducible deploy path.", 20, TEXT, False, PANEL2, LINE, True)
    ))
    slides.append(Slide(
        title("System Architecture", "Contracts, frontend, oracle adapter, subgraph, and governance control flow")
        + image_xml(2, 0.75, 1.25, 11.85, 5.75),
        [assets["architecture"]],
    ))
    slides.append(Slide(
        title("Smart Contract Implementation", "Core protocol surface")
        + bullet_box(0.7, 1.35, 3.85, 4.8, "Tokenization", ["GovernanceToken: voting power, permit, issuer role", "AssetBadgeNFT: proof badge / metadata", "RwaIssuerUpgradeable: V1 -> V2 path"], GREEN)
        + bullet_box(4.75, 1.35, 3.85, 4.8, "Yield + liquidity", ["RwaVault: tokenized shares and deposits", "ConstantProductAMM: 0.3% fee, slippage protection", "LP token accounting and reserve sync"], CYAN)
        + bullet_box(8.8, 1.35, 3.85, 4.8, "Control plane", ["ProtocolGovernor: propose/vote/queue/execute", "SimpleTimelock: 2-day delay", "ProtocolFactory: CREATE and CREATE2 deploys"], AMBER)
    ))
    slides.append(Slide(
        title("User Flows", "What the protocol demonstrates live")
        + bullet_box(0.7, 1.25, 3.85, 5.1, "Vault flow", ["User approves RWA", "Vault pulls assets", "Vault mints shares", "totalAssets reads token balance"], GREEN)
        + bullet_box(4.75, 1.25, 3.85, 5.1, "AMM flow", ["Liquidity provider adds RWA/USD", "Swap checks token and slippage", "k invariant is preserved after fee", "Reserves sync with balances"], CYAN)
        + bullet_box(8.8, 1.25, 3.85, 5.1, "Governance flow", ["Delegate voting power", "Create proposal", "Vote for/against", "Queue and execute via Timelock"], RED)
    ))
    slides.append(Slide(
        title("Frontend dApp", "React + Vite + ethers.js dashboard")
        + image_xml(2, 0.7, 1.2, 6.1, 4.95)
        + bullet_box(7.05, 1.35, 5.55, 4.55, "Frontend requirements covered", [
            "MetaMask wallet connection and chain detection",
            "Reads balance, voting power, vault assets, AMM reserves",
            "Writes delegate, deposit, swap, vote transactions",
            "Wrong-network and transaction error messages",
            "Subgraph activity section with live/fallback status",
        ], CYAN),
        [assets["frontend_overview"]],
    ))
    slides.append(Slide(
        title("Governance Demo", "Working proposal UI with live counters")
        + image_xml(2, 0.7, 1.25, 6.2, 4.8)
        + bullet_box(7.1, 1.25, 5.45, 4.8, "Live demo behavior", [
            "ID = 0 creates the next local proposal automatically",
            "ID = 1,2,3... creates missing proposals up to that ID",
            "Anvil time is advanced to open voting window",
            "For/Against counters read from the Governor contract",
            "Double voting reverts with ALREADY_VOTED",
        ], GREEN),
        [assets["frontend_governance"]],
    ))
    slides.append(Slide(
        title("Testing Evidence", "Unit, fuzz, invariant, and fork-test coverage")
        + image_xml(2, 0.75, 1.25, 6.0, 4.85)
        + bullet_box(7.05, 1.25, 5.55, 4.85, "Testing rubric", [
            "101 deterministic local tests pass without external RPC",
            "23 protocol tests + 78 requirement matrix tests",
            "5 invariant tests with 128k calls each",
            "Fork tests implemented for USDC, Uniswap V2, Chainlink",
            "Coverage report documents ~96.11% production src lines",
        ], AMBER),
        [assets["tests"]],
    ))
    slides.append(Slide(
        title("Security Evidence", "Slither clean and audit-backed design")
        + image_xml(2, 0.75, 1.25, 6.0, 4.85)
        + bullet_box(7.05, 1.25, 5.55, 4.85, "Security controls", [
            "ReentrancyGuard and CEI documented in audit",
            "AccessControlLite on privileged mint/admin actions",
            "Oracle rejects stale or invalid prices",
            "Timelock owns privileged protocol roles after deployment",
            "Reentrancy and access-control case studies fixed with tests",
        ], GREEN),
        [assets["security"]],
    ))
    slides.append(Slide(
        title("Subgraph + Indexed Data", "The Graph-ready protocol event model")
        + bullet_box(0.7, 1.25, 3.85, 4.9, "Entities", ["Token", "VaultDeposit", "Swap", "Proposal"], CYAN)
        + bullet_box(4.75, 1.25, 3.85, 4.9, "Handlers", ["CollateralIssued", "Deposit", "Swap", "ProposalCreated", "VoteCast", "Queued/Executed"], GREEN)
        + bullet_box(8.8, 1.25, 3.85, 4.9, "Frontend use", ["GraphQL POST to VITE_SUBGRAPH_URL", "Live activity stream", "Proposal list fallback for local demo", "No silent failure if hosted subgraph is unavailable"], AMBER)
    ))
    slides.append(Slide(
        title("Deployment Evidence", "Reproducible local deployment and L2-ready path")
        + image_xml(2, 0.75, 1.25, 6.0, 4.85)
        + bullet_box(7.05, 1.25, 5.55, 4.85, "Demo command", [
            "npm run local:demo",
            "Resets Anvil state and deploys contracts",
            "Starts frontend at 127.0.0.1:5173",
            "Fresh proposal state each presentation",
            "Arbitrum Sepolia dry-run documented; real verification needs faucet ETH",
        ], RED),
        [assets["deployment"]],
    ))
    slides.append(Slide(
        title("Defense Talking Points", "How to explain the project clearly in Q&A")
        + bullet_box(0.7, 1.25, 3.85, 5.1, "What to demo", ["Connect Local Anvil", "Show wallet RWA and voting power", "Deposit into vault", "Swap through AMM", "Vote on proposal ID 0/1/2"], GREEN)
        + bullet_box(4.75, 1.25, 3.85, 5.1, "What to say", ["The dApp sends real local transactions", "Vote counters come from contract state", "ALREADY_VOTED proves double-vote protection", "Timelock receives privileged roles"], CYAN)
        + bullet_box(8.8, 1.25, 3.85, 5.1, "Caveats", ["L2 faucet blocked real verification", "Subgraph is implementation-ready; hosted URL configurable", "Custom primitives are educational substitutes for OZ modules"], AMBER)
    ))
    return slides


def content_types(media: list[str], slide_count: int) -> str:
    overrides = [
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
        '<Default Extension="xml" ContentType="application/xml"/>',
        '<Default Extension="png" ContentType="image/png"/>',
        '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
        '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
        '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
        '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
    ]
    for i in range(1, slide_count + 1):
        overrides.append(f'<Override PartName="/ppt/slides/slide{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>')
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' + "".join(overrides) + "</Types>"


PRESENTATION_XML_TMPL = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
 <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
 <p:sldIdLst>{slide_ids}</p:sldIdLst>
 <p:sldSz cx="13333333" cy="7500000" type="wide"/>
 <p:notesSz cx="6858000" cy="9144000"/>
 <p:defaultTextStyle/>
</p:presentation>'''


def package_pptx(slides: list[Slide]) -> None:
    media_map: dict[Path, str] = {}
    media_counter = 1
    for slide in slides:
        for image in slide.images:
            if image not in media_map:
                media_map[image] = f"image{media_counter}.png"
                media_counter += 1

    slide_ids = "".join(f'<p:sldId id="{256 + i}" r:id="rId{i + 1}"/>' for i in range(1, len(slides) + 1))
    pres_rels = ['<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>']
    for i in range(1, len(slides) + 1):
        pres_rels.append(f'<Relationship Id="rId{i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i}.xml"/>')

    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", content_types(list(media_map.values()), len(slides)))
        z.writestr("_rels/.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>')
        z.writestr("ppt/presentation.xml", PRESENTATION_XML_TMPL.format(slide_ids=slide_ids))
        z.writestr("ppt/_rels/presentation.xml.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + "".join(pres_rels) + "</Relationships>")
        z.writestr("ppt/theme/theme1.xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="RWA"><a:themeElements><a:clrScheme name="RWA"><a:dk1><a:srgbClr val="07100E"/></a:dk1><a:lt1><a:srgbClr val="EDF7F2"/></a:lt1><a:dk2><a:srgbClr val="111A18"/></a:dk2><a:lt2><a:srgbClr val="C6D8D0"/></a:lt2><a:accent1><a:srgbClr val="4CE3A0"/></a:accent1><a:accent2><a:srgbClr val="57C9D4"/></a:accent2><a:accent3><a:srgbClr val="E9B961"/></a:accent3><a:accent4><a:srgbClr val="EF786F"/></a:accent4><a:accent5><a:srgbClr val="9FB2AA"/></a:accent5><a:accent6><a:srgbClr val="16211F"/></a:accent6><a:hlink><a:srgbClr val="57C9D4"/></a:hlink><a:folHlink><a:srgbClr val="4CE3A0"/></a:folHlink></a:clrScheme><a:fontScheme name="RWA"><a:majorFont><a:latin typeface="Segoe UI"/></a:majorFont><a:minorFont><a:latin typeface="Segoe UI"/></a:minorFont></a:fontScheme><a:fmtScheme name="RWA"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>')
        z.writestr("ppt/slideMasters/slideMaster1.xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld><p:clrMap bg1="dk1" tx1="lt1" bg2="dk2" tx2="lt2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>')
        z.writestr("ppt/slideMasters/_rels/slideMaster1.xml.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>')
        z.writestr("ppt/slideLayouts/slideLayout1.xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>')
        z.writestr("ppt/slideLayouts/_rels/slideLayout1.xml.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>')

        for i, slide in enumerate(slides, start=1):
            z.writestr(f"ppt/slides/slide{i}.xml", slide_xml(slide.xml))
            rel_images = []
            for image in slide.images:
                rel_images.append(media_map[image])
            z.writestr(f"ppt/slides/_rels/slide{i}.xml.rels", rels_xml(rel_images))
        for image, name in media_map.items():
            z.write(image, f"ppt/media/{name}")


def main() -> None:
    assets = make_assets()
    slides = build_slides(assets)
    package_pptx(slides)
    print(OUT)


if __name__ == "__main__":
    main()
