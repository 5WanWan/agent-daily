// Agent Daily — frontend (static, no backend, no build step).
// Only network calls: the user's wallet (window.ethereum) and public BSC RPC
// endpoints for read-only data. No credentials, no sessions, no tracking.

"use strict";

// ---------------------------------------------------------------------------
// Config — fill CONTRACT_ADDRESS + DEPLOY_BLOCK after the contract is deployed.
// ---------------------------------------------------------------------------
const REGISTRY_ADDRESS = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F"; // Agent ID registry
const CONTRACT_ADDRESS = ""; // TBD — AgentDaily on BSC mainnet (chain 56)
const DEPLOY_BLOCK = 0;      // TBD — block the contract was deployed in
const BSC_CHAIN_ID = 56;
const RPC_URLS = [
  "https://bsc-dataseed1.bnbchain.org",
  "https://bsc-dataseed2.bnbchain.org",
  "https://bsc.publicnode.com",
];
const DAY_SECONDS = 86400;
const LOG_CHUNK = 5000;

const AGENT_DAILY_ABI = [
  "function mintBadge()",
  "function checkIn()",
  "function hasBadge(address) view returns (bool)",
  "function badgeTokenId(address) view returns (uint256)",
  "function streakOf(address) view returns (uint256)",
  "function lastCheckIn(address) view returns (uint256)",
  "function totalCheckIns(address) view returns (uint256)",
  "function totalBadges() view returns (uint256)",
  "event BadgeMinted(address indexed user, uint256 indexed tokenId)",
  "event CheckedIn(address indexed user, uint256 streak, uint256 totalCheckIns, uint256 timestamp)",
];
const REGISTRY_ABI = ["function balanceOf(address) view returns (uint256)"];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
let provider = null;
let signer = null;
let account = null;
let daily = null;
let lastCheckInTs = 0;
let countdownTimer = null;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function $(id) { return document.getElementById(id); }
function shortAddr(a) { return a ? a.slice(0, 6) + "…" + a.slice(-4) : "—"; }
function fmtTime(ts) {
  if (!ts) return "never";
  return new Date(ts * 1000).toLocaleString();
}
function fmtCountdown(seconds) {
  if (seconds <= 0) return "Ready — you can check in now.";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return h + "h " + String(m).padStart(2, "0") + "m " + String(s).padStart(2, "0") + "s";
}
function setTxStatus(msg) { $("txStatus").textContent = msg || ""; }
function showError(el, msg) {
  el.style.display = msg ? "block" : "none";
  el.textContent = msg || "";
}

// ---------------------------------------------------------------------------
// Wallet connection
// ---------------------------------------------------------------------------
async function connectWallet() {
  if (typeof window.ethers === "undefined") {
    alert("Could not load the ethers.js library (CDN). Check your connection and reload the page.");
    return;
  }
  if (!window.ethereum) {
    alert("No wallet found. Install a wallet that injects window.ethereum (e.g. a browser wallet) and try again.");
    return;
  }
  try {
    provider = new ethers.providers.Web3Provider(window.ethereum, "any");
    await provider.send("eth_requestAccounts", []);
    signer = provider.getSigner();
    account = await signer.getAddress();
    $("walletInfo").textContent = "Connected: " + account;
    $("status-section").style.display = "block";
    $("action-section").style.display = "block";
    const net = await provider.getNetwork();
    $("networkWarn").style.display = net.chainId === BSC_CHAIN_ID ? "none" : "block";
    if (CONTRACT_ADDRESS) {
      daily = new ethers.Contract(CONTRACT_ADDRESS, AGENT_DAILY_ABI, signer);
    }
    await refreshStatus();
    window.ethereum.on("accountsChanged", function () { location.reload(); });
    window.ethereum.on("chainChanged", function () { location.reload(); });
  } catch (err) {
    console.error(err);
    alert("Connection failed or was rejected in your wallet: " + (err && err.message ? err.message : err));
  }
}

// ---------------------------------------------------------------------------
// Status reads
// ---------------------------------------------------------------------------
async function refreshStatus() {
  showError($("statusError"), "");
  try {
    const registry = new ethers.Contract(REGISTRY_ADDRESS, REGISTRY_ABI, provider);
    const agentBal = await registry.balanceOf(account);
    const hasId = agentBal.gt(0);
    $("agentIdStatus").textContent = hasId ? "Yes — you hold an Agent ID" : "No Agent ID found on this address";

    if (!CONTRACT_ADDRESS) {
      $("badgeStatus").textContent = "Contract not deployed yet";
      $("streak").textContent = "—";
      $("totalCheckIns").textContent = "—";
      $("lastCheckIn").textContent = "—";
      $("countdown").textContent = "—";
      $("actionHint").textContent = "The Agent Daily contract has not been deployed yet. Minting and check-in will unlock after deployment.";
      return;
    }

    const hasBadge = await daily.hasBadge(account);
    if (hasBadge) {
      const tokenId = await daily.badgeTokenId(account);
      $("badgeStatus").textContent = "Yes — soulbound badge minted";
      $("badgeTokenId").textContent = "(token #" + tokenId.toString() + ")";
    } else {
      $("badgeStatus").textContent = "Not yet minted";
      $("badgeTokenId").textContent = "";
    }
    const streak = await daily.streakOf(account);
    const total = await daily.totalCheckIns(account);
    lastCheckInTs = (await daily.lastCheckIn(account)).toNumber();
    $("streak").textContent = streak.toString();
    $("totalCheckIns").textContent = total.toString();
    $("lastCheckIn").textContent = fmtTime(lastCheckInTs);
    updateCountdown();

    const canMint = hasId && !hasBadge;
    const canCheckIn = hasBadge && Date.now() / 1000 >= lastCheckInTs + DAY_SECONDS;
    $("mintBtn").style.display = canMint ? "inline-block" : "none";
    $("checkInBtn").style.display = canCheckIn ? "inline-block" : "none";
    if (!hasId) {
      $("actionHint").textContent = "You need an Agent ID to mint the badge.";
    } else if (!hasBadge) {
      $("actionHint").textContent = "You hold an Agent ID — you can mint your free badge (gas only).";
    } else if (!canCheckIn) {
      $("actionHint").textContent = "Badge minted. Come back after 24h from your last check-in to extend your streak.";
    } else {
      $("actionHint").textContent = "Your daily check-in is ready.";
    }
  } catch (err) {
    console.error(err);
    showError($("statusError"), "Could not read on-chain status: " + (err && err.message ? err.message : err));
  }
}

function updateCountdown() {
  if (!lastCheckInTs) { $("countdown").textContent = "Ready — you can check in now."; return; }
  const remaining = lastCheckInTs + DAY_SECONDS - Math.floor(Date.now() / 1000);
  $("countdown").textContent = fmtCountdown(remaining);
  if (countdownTimer) clearInterval(countdownTimer);
  countdownTimer = setInterval(function () {
    const left = lastCheckInTs + DAY_SECONDS - Math.floor(Date.now() / 1000);
    $("countdown").textContent = fmtCountdown(left);
    if (left <= 0) {
      clearInterval(countdownTimer);
      refreshStatus();
    }
  }, 1000);
}

// ---------------------------------------------------------------------------
// Transactions (always confirmed by the user in their own wallet)
// ---------------------------------------------------------------------------
async function mintBadge() {
  if (!daily) return;
  setTxStatus("Waiting for your confirmation in your wallet…");
  try {
    const tx = await daily.mintBadge();
    setTxStatus("Mint submitted: " + tx.hash + " — waiting for confirmation…");
    await tx.wait();
    setTxStatus("Badge minted! Transaction: " + tx.hash);
    await refreshStatus();
  } catch (err) {
    console.error(err);
    setTxStatus("Mint failed or rejected: " + (err && err.message ? err.message : err));
  }
}

async function checkIn() {
  if (!daily) return;
  setTxStatus("Waiting for your confirmation in your wallet…");
  try {
    const tx = await daily.checkIn();
    setTxStatus("Check-in submitted: " + tx.hash + " — waiting for confirmation…");
    await tx.wait();
    setTxStatus("Checked in! Transaction: " + tx.hash);
    await refreshStatus();
    await loadLeaderboard();
  } catch (err) {
    console.error(err);
    setTxStatus("Check-in failed or rejected: " + (err && err.message ? err.message : err));
  }
}

// ---------------------------------------------------------------------------
// Leaderboard — reads CheckedIn events from public RPC, chunked.
// The latest event per address carries that address's current streak
// (streaks only change on check-in, and every check-in emits an event).
// ---------------------------------------------------------------------------
async function loadLeaderboard() {
  const list = $("leaderboard");
  showError($("leaderboardError"), "");
  if (!CONTRACT_ADDRESS || !DEPLOY_BLOCK) {
    list.innerHTML = "<li>Leaderboard unlocks after the contract is deployed.</li>";
    return;
  }
  list.innerHTML = "<li>Loading…</li>";
  let lastErr = null;
  for (const url of RPC_URLS) {
    try {
      const rpc = new ethers.providers.JsonRpcProvider(url);
      const iface = new ethers.utils.Interface(AGENT_DAILY_ABI);
      const topic = iface.getEventTopic("CheckedIn");
      const latest = await rpc.getBlockNumber();
      const best = new Map(); // address -> { streak, timestamp }
      for (let from = DEPLOY_BLOCK; from <= latest; from += LOG_CHUNK) {
        const to = Math.min(from + LOG_CHUNK - 1, latest);
        const logs = await rpc.getLogs({ address: CONTRACT_ADDRESS, fromBlock: from, toBlock: to, topics: [topic] });
        for (const log of logs) {
          const parsed = iface.parseLog(log);
          const user = parsed.args.user;
          const streak = parsed.args.streak.toNumber();
          const ts = parsed.args.timestamp.toNumber();
          const prev = best.get(user);
          if (!prev || ts >= prev.timestamp) best.set(user, { streak: streak, timestamp: ts });
        }
      }
      const rows = Array.from(best.entries())
        .map(function (kv) { return { user: kv[0], streak: kv[1].streak }; })
        .sort(function (a, b) { return b.streak - a.streak; })
        .slice(0, 10);
      if (rows.length === 0) {
        list.innerHTML = "<li>No check-ins yet. Be the first.</li>";
      } else {
        list.innerHTML = rows.map(function (r, i) {
          return "<li>#" + (i + 1) + " " + shortAddr(r.user) + " — streak " + r.streak + "</li>";
        }).join("");
      }
      return;
    } catch (err) {
      lastErr = err;
      console.warn("leaderboard RPC failed:", url, err);
    }
  }
  list.innerHTML = "<li>Leaderboard unavailable.</li>";
  showError($("leaderboardError"), "Could not load the leaderboard from public RPC endpoints. Your on-chain data is unaffected — please try again later. (" + (lastErr && lastErr.message ? lastErr.message : lastErr) + ")");
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", function () {
  $("connectBtn").addEventListener("click", connectWallet);
  $("mintBtn").addEventListener("click", mintBadge);
  $("checkInBtn").addEventListener("click", checkIn);
  $("refreshLbBtn").addEventListener("click", loadLeaderboard);
  if (CONTRACT_ADDRESS) {
    $("contractAddr").textContent = CONTRACT_ADDRESS;
    const link = $("bscscanLink");
    link.href = "https://bscscan.com/address/" + CONTRACT_ADDRESS;
  }
  loadLeaderboard();
});
