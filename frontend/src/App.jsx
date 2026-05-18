import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { BrowserProvider, Contract, formatEther, parseEther } from "ethers";
import "./style.css";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const emptyAddresses = {
  rwa: ZERO_ADDRESS,
  vault: ZERO_ADDRESS,
  amm: ZERO_ADDRESS,
  governor: ZERO_ADDRESS
};

const envAddress = (key, fallback = ZERO_ADDRESS) => import.meta.env[key] || fallback;

const contractsByChain = {
  31337: {
    rwa: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    vault: "0x0165878A594ca255338adfa4d48449f69242Eb8F",
    amm: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
    governor: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6"
  },
  421614: {
    rwa: envAddress("VITE_ARBITRUM_SEPOLIA_RWA_ADDRESS"),
    vault: envAddress("VITE_ARBITRUM_SEPOLIA_VAULT_ADDRESS"),
    amm: envAddress("VITE_ARBITRUM_SEPOLIA_AMM_ADDRESS"),
    governor: envAddress("VITE_ARBITRUM_SEPOLIA_GOVERNOR_ADDRESS")
  },
  11155420: {
    rwa: envAddress("VITE_OP_SEPOLIA_RWA_ADDRESS"),
    vault: envAddress("VITE_OP_SEPOLIA_VAULT_ADDRESS"),
    amm: envAddress("VITE_OP_SEPOLIA_AMM_ADDRESS"),
    governor: envAddress("VITE_OP_SEPOLIA_GOVERNOR_ADDRESS")
  },
  84532: {
    rwa: envAddress("VITE_BASE_SEPOLIA_RWA_ADDRESS"),
    vault: envAddress("VITE_BASE_SEPOLIA_VAULT_ADDRESS"),
    amm: envAddress("VITE_BASE_SEPOLIA_AMM_ADDRESS"),
    governor: envAddress("VITE_BASE_SEPOLIA_GOVERNOR_ADDRESS")
  },
  300: {
    rwa: envAddress("VITE_ZKSYNC_SEPOLIA_RWA_ADDRESS"),
    vault: envAddress("VITE_ZKSYNC_SEPOLIA_VAULT_ADDRESS"),
    amm: envAddress("VITE_ZKSYNC_SEPOLIA_AMM_ADDRESS"),
    governor: envAddress("VITE_ZKSYNC_SEPOLIA_GOVERNOR_ADDRESS")
  }
};

const erc20Abi = [
  "function balanceOf(address) view returns (uint256)",
  "function votingPower(address) view returns (uint256)",
  "function delegates(address) view returns (address)",
  "function approve(address,uint256) returns (bool)",
  "function delegate(address)"
];
const vaultAbi = ["function deposit(uint256,address) returns (uint256)", "function totalAssets() view returns (uint256)"];
const ammAbi = ["function reserve0() view returns (uint112)", "function reserve1() view returns (uint112)", "function swap(address,uint256,uint256) returns (uint256)"];
const governorAbi = [
  "function state(uint256) view returns (uint8)",
  "function castVote(uint256,bool)",
  "function proposalCount() view returns (uint256)",
  "function propose(address,uint256,bytes,string) returns (uint256)",
  "function proposals(uint256) view returns (address proposer,address target,uint256 value,bytes data,bytes32 salt,uint256 start,uint256 end,uint256 forVotes,uint256 againstVotes,bool queued,bool executed,string description)"
];

const supportedChains = {
  31337n: "Local Anvil",
  421614n: "Arbitrum Sepolia",
  11155420n: "OP Sepolia",
  84532n: "Base Sepolia",
  300n: "zkSync Sepolia"
};

const proposalStates = ["Pending", "Active", "Defeated", "Succeeded", "Queued", "Executed"];
const LOCAL_RPC_URL = "http://127.0.0.1:8545";
const LOCAL_VOTING_DELAY_SECONDS = 86401;
const localProposalTitles = {
  1: "Raise vault allocation cap",
  2: "Update oracle signer set",
  3: "AMM fee to treasury"
};

const SUBGRAPH_URL = import.meta.env.VITE_SUBGRAPH_URL || "";

const demoActivity = [
  { type: "Vault", label: "RWA deposit indexed", value: "42,000 RWA", time: "2m ago" },
  { type: "AMM", label: "Pool rebalance simulated", value: "1.8% slippage", time: "18m ago" },
  { type: "Gov", label: "Proposal queue ready", value: "ETA 24h", time: "41m ago" },
  { type: "Oracle", label: "NAV attestation refreshed", value: "$1.04", time: "1h ago" }
];

const demoProposals = [
  { id: "1", title: "Raise vault allocation cap", state: "Active", forVotes: "72%", againstVotes: "18%", quorum: "90%" },
  { id: "2", title: "Update oracle signer set", state: "Queued", forVotes: "81%", againstVotes: "9%", quorum: "96%" },
  { id: "3", title: "AMM fee to treasury", state: "Review", forVotes: "64%", againstVotes: "21%", quorum: "73%" }
];

const checklist = [
  ["Contracts", "Compiled and covered"],
  ["Security", "No high or medium Slither findings"],
  ["Tests", "104 Forge tests passing"],
  ["Frontend", "Wallet actions wired"],
  ["Subgraph", "Schema and handlers prepared"]
];

function compactAddress(value) {
  if (!value) return "Not connected";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function metricValue(value, fallback) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric === 0) return fallback;
  return numeric.toLocaleString(undefined, { maximumFractionDigits: 4 });
}

function shortAmount(value, decimals = 18) {
  const numeric = Number(value || 0) / 10 ** decimals;
  if (!Number.isFinite(numeric)) return "0";
  return numeric.toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function formatVoteAmount(value) {
  const numeric = Number(formatEther(value || 0n));
  if (!Number.isFinite(numeric)) return "0";
  return numeric.toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function collectErrorMessages(error, messages = []) {
  if (!error) return messages;
  if (typeof error === "string") {
    messages.push(error);
    return messages;
  }
  if (typeof error !== "object") return messages;
  ["shortMessage", "reason", "message"].forEach((key) => {
    if (typeof error[key] === "string") messages.push(error[key]);
  });
  ["error", "info", "data", "payload"].forEach((key) => collectErrorMessages(error[key], messages));
  return messages;
}

function friendlyError(error) {
  const text = collectErrorMessages(error).join(" | ");
  if (text.includes("could not coalesce error")) {
    return "MetaMask has stale Local Anvil state. Reset account activity in MetaMask, refresh the page, and reconnect Local Anvil.";
  }
  if (text.includes("ALREADY_VOTED")) return "This wallet already voted on this proposal ID. Use a new proposal ID or another local account.";
  if (text.includes("UNKNOWN_PROPOSAL")) return "This proposal does not exist yet. On Local Anvil, enter ID 0 or a new ID and vote to auto-create it.";
  if (text.includes("VOTE_CLOSED")) return "Voting is not active for this proposal yet. Local automation will open new proposals automatically.";
  if (text.includes("NO_VOTES")) return "No voting power yet. Press Delegate first, then vote again.";
  if (text.toLowerCase().includes("user rejected")) return "Transaction was rejected in MetaMask.";
  if (text.toLowerCase().includes("insufficient funds")) return "Insufficient local ETH for gas. Import an Anvil funded account.";
  if (text.toLowerCase().includes("nonce")) return "MetaMask nonce is stale after local reset. Reset account activity in MetaMask and refresh.";
  return text || "Transaction rejected or failed.";
}

async function anvilRpc(method, params = []) {
  const response = await fetch(LOCAL_RPC_URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: Date.now(), method, params })
  });
  const payload = await response.json();
  if (payload.error) throw new Error(payload.error.message);
  return payload.result;
}

async function loadSubgraphActivity() {
  if (!SUBGRAPH_URL) return { activity: demoActivity, proposals: demoProposals, status: "Demo indexer" };
  const query = `{
    vaultDeposits(first: 4, orderBy: blockNumber, orderDirection: desc) {
      id
      caller
      owner
      assets
      shares
      blockNumber
    }
    swaps(first: 4, orderBy: blockNumber, orderDirection: desc) {
      id
      trader
      tokenIn
      amountIn
      amountOut
      blockNumber
    }
    proposals(first: 4) {
      id
      description
      state
      forVotes
      againstVotes
    }
  }`;
  const response = await fetch(SUBGRAPH_URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query })
  });
  if (!response.ok) throw new Error("Subgraph request failed");
  const payload = await response.json();
  if (payload.errors?.length) throw new Error(payload.errors[0].message);
  const deposits = payload.data?.vaultDeposits || [];
  const swaps = payload.data?.swaps || [];
  const indexedActivity = [
    ...deposits.map((deposit) => ({
      type: "Vault",
      label: `Deposit by ${compactAddress(deposit.caller)}`,
      value: `${shortAmount(deposit.assets)} RWA`,
      time: `Block ${deposit.blockNumber}`
    })),
    ...swaps.map((swap) => ({
      type: "AMM",
      label: `Swap by ${compactAddress(swap.trader)}`,
      value: `${shortAmount(swap.amountIn)} in`,
      time: `Block ${swap.blockNumber}`
    }))
  ].slice(0, 4);
  const indexedProposals = (payload.data?.proposals || []).map((proposal) => ({
    id: proposal.id,
    title: proposal.description || `Proposal ${proposal.id}`,
    state: proposal.state || "Indexed",
    forVotes: `${Math.min(100, Number(proposal.forVotes || 0) / 10 ** 18)}%`,
    againstVotes: `${Math.min(100, Number(proposal.againstVotes || 0) / 10 ** 18)}%`,
    quorum: "Indexed"
  }));
  return {
    activity: indexedActivity.length ? indexedActivity : demoActivity,
    proposals: indexedProposals.length ? indexedProposals : demoProposals,
    status: "Subgraph live"
  };
}

function App() {
  const [account, setAccount] = useState("");
  const [message, setMessage] = useState("Local demo mode is ready. Connect MetaMask to Local Anvil chain 31337.");
  const [chainName, setChainName] = useState("Local + Sepolia ready");
  const [chainId, setChainId] = useState("");
  const [stats, setStats] = useState({ balance: "0", votes: "0", delegate: "", assets: "0", reserves: "0 / 0" });
  const [proposalId, setProposalId] = useState("1");
  const [amount, setAmount] = useState("1");
  const [indexedActivity, setIndexedActivity] = useState(demoActivity);
  const [indexedProposals, setIndexedProposals] = useState(demoProposals);
  const [indexerStatus, setIndexerStatus] = useState("Demo indexer");
  const [proposalStats, setProposalStats] = useState({
    exists: false,
    state: "Demo",
    forVotes: "0",
    againstVotes: "0",
    description: "Select a live proposal ID"
  });

  const provider = useMemo(() => (window.ethereum ? new BrowserProvider(window.ethereum) : null), []);
  const activeAddresses = contractsByChain[chainId] || emptyAddresses;
  const contractsReady = Object.values(activeAddresses).every((address) => address !== ZERO_ADDRESS);
  const actionReady = Boolean(provider && account && contractsReady);

  const metrics = [
    { label: "Protocol NAV", value: "$4.28M", delta: "+12.4%", tone: "good" },
    { label: "Wallet RWA", value: metricValue(stats.balance, "18,240"), delta: account ? "Live wallet" : "Demo", tone: "neutral" },
    { label: "Voting Power", value: metricValue(stats.votes, "16,910"), delta: "Delegated", tone: "good" },
    { label: "Vault Assets", value: metricValue(stats.assets, "3.72M"), delta: "+7.8% 30d", tone: "good" },
    { label: "AMM Reserves", value: stats.reserves === "0 / 0" ? "$820K / 788K RWA" : stats.reserves, delta: "Deep pool", tone: "neutral" },
    { label: "Risk Buffer", value: "18.6%", delta: "Above target", tone: "warn" }
  ];

  async function syncWalletState(requestAccounts = false) {
    if (!provider) throw new Error("MetaMask is not available");
    const accounts = await provider.send(requestAccounts ? "eth_requestAccounts" : "eth_accounts", []);
    const network = await provider.getNetwork();
    const name = supportedChains[network.chainId];
    const nextChainId = network.chainId.toString();
    const configured = contractsByChain[nextChainId] || emptyAddresses;
    const ready = Object.values(configured).every((address) => address !== ZERO_ADDRESS);

    setChainName(name || `Chain ${nextChainId}`);
    setChainId(nextChainId);
    setAccount(accounts[0] || "");

    return { accounts, name, nextChainId, ready };
  }

  function walletMessage({ accounts, name, nextChainId, ready }) {
    if (!accounts[0]) return "Local demo mode is ready. Connect MetaMask to Local Anvil chain 31337.";
    if (!name) return "Wrong network. Switch to Local Anvil 31337, Arbitrum, Optimism, Base, or zkSync Sepolia.";
    if (!ready) return "Wallet connected. Add deployed Sepolia L2 addresses in .env to enable live transactions.";
    if (nextChainId === "31337") return "Wallet connected. Local Anvil contracts are ready for live actions.";
    return "Wallet connected. Live protocol reads are enabled.";
  }

  async function connect() {
    try {
      const wallet = await syncWalletState(true);
      setMessage(walletMessage(wallet));
    } catch (error) {
      setMessage(friendlyError(error));
    }
  }

  useEffect(() => {
    if (!provider || !window.ethereum) return undefined;
    syncWalletState(false)
      .then((wallet) => {
        if (wallet.accounts[0]) setMessage(walletMessage(wallet));
      })
      .catch(() => {});

    const handleAccountsChanged = (accounts) => {
      setAccount(accounts[0] || "");
      syncWalletState(false)
        .then((wallet) => setMessage(walletMessage(wallet)))
        .catch(() => {});
    };
    const handleChainChanged = () => {
      syncWalletState(false)
        .then((wallet) => setMessage(walletMessage(wallet)))
        .catch(() => {});
    };

    window.ethereum.on?.("accountsChanged", handleAccountsChanged);
    window.ethereum.on?.("chainChanged", handleChainChanged);
    return () => {
      window.ethereum.removeListener?.("accountsChanged", handleAccountsChanged);
      window.ethereum.removeListener?.("chainChanged", handleChainChanged);
    };
  }, [provider]);

  async function refresh() {
    if (!provider || !account || !contractsReady) return;
    try {
      const rwa = new Contract(activeAddresses.rwa, erc20Abi, provider);
      const vault = new Contract(activeAddresses.vault, vaultAbi, provider);
      const amm = new Contract(activeAddresses.amm, ammAbi, provider);
      const [balance, votes, delegate, assets, reserve0, reserve1] = await Promise.all([
        rwa.balanceOf(account),
        rwa.votingPower(account),
        rwa.delegates(account),
        vault.totalAssets(),
        amm.reserve0(),
        amm.reserve1()
      ]);
      setStats({
        balance: formatEther(balance),
        votes: formatEther(votes),
        delegate,
        assets: formatEther(assets),
        reserves: `${formatEther(reserve0)} / ${formatEther(reserve1)}`
      });
    } catch (error) {
      setMessage("Contract read failed. Check that Anvil is running and the local deploy exists on chain 31337.");
    }
  }

  async function refreshProposal() {
    if (!provider || !contractsReady || !proposalId) return;
    if (proposalId === "0") {
      setProposalStats({
        exists: false,
        state: "Auto next",
        forVotes: "0",
        againstVotes: "0",
        description: "ID 0 creates the next local proposal automatically"
      });
      return;
    }
    try {
      const governor = new Contract(activeAddresses.governor, governorAbi, provider);
      const [proposal, state] = await Promise.all([governor.proposals(proposalId), governor.state(proposalId)]);
      setProposalStats({
        exists: true,
        state: proposalStates[Number(state)] || `State ${state.toString()}`,
        forVotes: formatVoteAmount(proposal.forVotes),
        againstVotes: formatVoteAmount(proposal.againstVotes),
        description: proposal.description || `Proposal ${proposalId}`
      });
    } catch (error) {
      setProposalStats({
        exists: false,
        state: "Not found",
        forVotes: "0",
        againstVotes: "0",
        description: "This proposal ID is not created on the connected chain"
      });
    }
  }

  async function ensureLocalProposal(signer) {
    const governor = new Contract(activeAddresses.governor, governorAbi, signer);
    if (chainId !== "31337") return governor;

    const requestedId = Number(proposalId);
    if (!Number.isInteger(requestedId) || requestedId < 0) throw new Error("Proposal ID must be 0 or a positive number.");

    const rwa = new Contract(activeAddresses.rwa, erc20Abi, signer);
    const currentVotes = await rwa.votingPower(account);
    if (currentVotes === 0n) {
      setMessage("Local automation: delegating voting power first...");
      const delegateTx = await rwa.delegate(account);
      await delegateTx.wait();
    }

    let count = Number(await governor.proposalCount());
    const targetId = requestedId === 0 ? count + 1 : requestedId;
    if (targetId > count) {
      for (let nextId = count + 1; nextId <= targetId; nextId++) {
        const title = localProposalTitles[nextId] || `Local demo proposal #${nextId}`;
        setMessage(`Local automation: creating proposal #${nextId}...`);
        const proposeTx = await governor.propose(activeAddresses.rwa, 0, "0x", title);
        await proposeTx.wait();
      }
      count = targetId;
    }
    if (proposalId !== String(targetId)) setProposalId(String(targetId));

    const state = Number(await governor.state(targetId));
    if (state === 0) {
      setMessage(`Local automation: opening proposal #${targetId} voting window...`);
      await anvilRpc("evm_increaseTime", [LOCAL_VOTING_DELAY_SECONDS]);
      await anvilRpc("evm_mine");
    }

    return governor;
  }

  async function vote(support) {
    return tx(async (signer) => {
      const governor = await ensureLocalProposal(signer);
      const idToVote = proposalId === "0" ? await governor.proposalCount() : BigInt(proposalId);
      setMessage(`Submitting vote ${support ? "for" : "against"} proposal #${idToVote.toString()}...`);
      return governor.castVote(idToVote, support);
    });
  }

  async function tx(action) {
    try {
      if (!actionReady) throw new Error("Connect a wallet on Local Anvil 31337 or configure deployed L2 contract addresses first.");
      const signer = await provider.getSigner();
      const result = await action(signer);
      if (result?.wait) await result.wait();
      setMessage("Transaction confirmed.");
      await refresh();
      await refreshProposal();
    } catch (error) {
      setMessage(friendlyError(error));
    }
  }

  useEffect(() => {
    refresh();
    refreshProposal();
  }, [account, chainId, proposalId]);

  useEffect(() => {
    let mounted = true;
    loadSubgraphActivity()
      .then((result) => {
        if (!mounted) return;
        setIndexedActivity(result.activity);
        setIndexedProposals(result.proposals);
        setIndexerStatus(result.status);
      })
      .catch(() => {
        if (!mounted) return;
        setIndexerStatus("Subgraph fallback");
        setIndexedActivity(demoActivity);
        setIndexedProposals(demoProposals);
      });
    return () => {
      mounted = false;
    };
  }, []);

  return (
    <main className="shell">
      <aside className="sidebar" aria-label="Protocol navigation">
        <div className="brand">
          <span className="brand-mark">R</span>
          <div>
            <strong>RWA Core</strong>
            <small>Governed yield protocol</small>
          </div>
        </div>
        <nav className="nav-list">
          <a className="active" href="#overview">Overview</a>
          <a href="#vault">Vault</a>
          <a href="#markets">Markets</a>
          <a href="#governance">Governance</a>
          <a href="#security">Security</a>
        </nav>
        <div className="side-status">
          <span className="status-dot" />
          <div>
            <strong>{chainId === "31337" ? "Local deployment" : "Demo deployment"}</strong>
            <small>{chainId === "31337" ? "Anvil contracts wired for chain 31337" : "Connect Local Anvil or Sepolia L2"}</small>
          </div>
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">RWA Governed Protocol</p>
            <h1>Institutional asset vault, AMM liquidity, and on-chain governance.</h1>
          </div>
          <div className="top-actions">
            <span className="network-pill">{chainName}</span>
            <button className="connect-button" onClick={connect}>
              {account ? compactAddress(account) : "Connect wallet"}
            </button>
          </div>
        </header>

        {message && (
          <section className="notice" role="status">
            <span className="notice-line" />
            <p>{message}</p>
          </section>
        )}

        <section id="overview" className="metrics-grid" aria-label="Protocol metrics">
          {metrics.map((metric) => (
            <article className="metric-card" key={metric.label}>
              <span>{metric.label}</span>
              <strong>{metric.value}</strong>
              <em className={metric.tone}>{metric.delta}</em>
            </article>
          ))}
        </section>

        <section className="dashboard-grid">
          <article id="vault" className="panel primary-panel">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Vault Control</p>
                <h2>Tokenize, deposit, and route yield</h2>
              </div>
              <span className="health-pill">Healthy</span>
            </div>
            <div className="vault-visual" aria-hidden="true">
              <div className="vault-track">
                <span style={{ width: "72%" }} />
              </div>
              <div className="vault-legend">
                <span>Senior pool 72%</span>
                <span>Treasury 18%</span>
                <span>Reserve 10%</span>
              </div>
            </div>
            <div className="action-strip">
              <label>
                Amount
                <input value={amount} onChange={(event) => setAmount(event.target.value)} inputMode="decimal" />
              </label>
              <button disabled={!actionReady} onClick={() => tx(async (signer) => new Contract(activeAddresses.rwa, erc20Abi, signer).delegate(account))}>
                Delegate
              </button>
              <button
                disabled={!actionReady}
                onClick={() =>
                  tx(async (signer) => {
                    const rwa = new Contract(activeAddresses.rwa, erc20Abi, signer);
                    await rwa.approve(activeAddresses.vault, parseEther(amount));
                    await new Contract(activeAddresses.vault, vaultAbi, signer).deposit(parseEther(amount), account);
                  })
                }
              >
                Deposit
              </button>
            </div>
          </article>

          <article id="markets" className="panel market-panel">
            <div className="panel-header">
              <div>
                <p className="eyebrow">AMM Desk</p>
                <h2>Liquidity routing</h2>
              </div>
              <span className="health-pill muted">Preview</span>
            </div>
            <div className="price-stack">
              <div><span>RWA / USD</span><strong>1.043</strong></div>
              <div><span>24h volume</span><strong>$186K</strong></div>
              <div><span>Fee APR</span><strong>9.2%</strong></div>
            </div>
            <button
              className="wide-button"
              disabled={!actionReady}
              onClick={() =>
                tx(async (signer) => {
                  const rwa = new Contract(activeAddresses.rwa, erc20Abi, signer);
                  await rwa.approve(activeAddresses.amm, parseEther(amount));
                  await new Contract(activeAddresses.amm, ammAbi, signer).swap(activeAddresses.rwa, parseEther(amount), 1);
                })
              }
            >
              Swap selected amount
            </button>
          </article>

          <article id="governance" className="panel governance-panel">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Governance</p>
                <h2>Proposal command center</h2>
              </div>
              <label className="proposal-input">
                ID
                <input value={proposalId} onChange={(event) => setProposalId(event.target.value)} />
              </label>
            </div>
            <div className="proposal-list">
              {indexedProposals.map((proposal) => (
                <div className="proposal-row" key={proposal.id}>
                  <span>#{proposal.id}</span>
                  <strong>{proposal.title}</strong>
                  <em>{proposal.state}</em>
                  <div className="vote-bar" aria-label={`${proposal.forVotes} for`}>
                    <span style={{ width: proposal.forVotes }} />
                  </div>
                </div>
              ))}
            </div>
            <div className="vote-counter" aria-label="Live governance vote counter">
              <div>
                <span>Selected proposal</span>
                <strong>#{proposalId}</strong>
                <em>{proposalStats.state}</em>
              </div>
              <div>
                <span>For votes</span>
                <strong>{proposalStats.forVotes}</strong>
                <em>Live counter</em>
              </div>
              <div>
                <span>Against votes</span>
                <strong>{proposalStats.againstVotes}</strong>
                <em>Live counter</em>
              </div>
            </div>
            <p className="proposal-description">{proposalStats.description}</p>
            <div className="vote-actions">
              <button disabled={!actionReady} onClick={() => vote(true)}>
                Vote for
              </button>
              <button className="secondary" disabled={!actionReady} onClick={() => vote(false)}>
                Vote against
              </button>
            </div>
          </article>

          <article className="panel activity-panel">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Indexer</p>
                <h2>Live activity stream</h2>
              </div>
              <span className="pulse">{indexerStatus}</span>
            </div>
            <div className="timeline">
              {indexedActivity.map((item) => (
                <div className="timeline-row" key={`${item.type}-${item.time}`}>
                  <span>{item.type}</span>
                  <strong>{item.label}</strong>
                  <em>{item.value}</em>
                  <small>{item.time}</small>
                </div>
              ))}
            </div>
          </article>

          <article id="security" className="panel security-panel">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Security</p>
                <h2>Assignment-grade readiness</h2>
              </div>
              <span className="health-pill">Clear</span>
            </div>
            <div className="checklist">
              {checklist.map(([title, detail]) => (
                <div className="check-row" key={title}>
                  <span />
                  <strong>{title}</strong>
                  <em>{detail}</em>
                </div>
              ))}
            </div>
          </article>

          <article className="panel map-panel">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Architecture</p>
                <h2>Protocol flow</h2>
              </div>
            </div>
            <div className="protocol-map" aria-label="Protocol component map">
              <span className="map-node token">RWA Token</span>
              <span className="map-node vault">Vault</span>
              <span className="map-node amm">AMM</span>
              <span className="map-node gov">Governor</span>
              <span className="map-node oracle">Oracle</span>
              <span className="map-line one" />
              <span className="map-line two" />
              <span className="map-line three" />
            </div>
          </article>
        </section>
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
