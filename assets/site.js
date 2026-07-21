/* Confyro — shared site script. Progressive enhancement only:
   every page reads fine with JavaScript disabled. No trackers. */
(function () {
  "use strict";
  var root = document.documentElement;
  root.classList.add("js");
  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // masthead hairline appears once the page is in motion
  var topbar = document.getElementById("topbar");
  if (topbar) {
    // hysteresis: a single threshold at the top of the page let the header
    // toggle-fight the scroll position when scrolling back up
    var onScroll = function () {
      var y = window.scrollY;
      if (y > 120) topbar.classList.add("scrolled");
      else if (y < 40) topbar.classList.remove("scrolled");
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  // scroll reveals — content is visible without JS; this only choreographs it
  var revealed = document.querySelectorAll(".rv, .rvh, .gaterail");
  if (reduced || !("IntersectionObserver" in window)) {
    revealed.forEach(function (el) { el.classList.add("in"); });
  } else {
    var seen = 0;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var el = entry.target;
        el.style.transitionDelay = Math.min(seen++ % 4, 3) * 90 + "ms";
        el.classList.add("in");
        io.unobserve(el);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    revealed.forEach(function (el) { io.observe(el); });
  }

  // the hero performs shortly after load (headline mask, then the card)
  var heroH = document.querySelector(".hero .rvh");
  if (heroH) {
    window.setTimeout(function () { heroH.classList.add("in"); }, reduced ? 0 : 80);
  }
  // hero laptop demo: drag-in, check, report — loops while visible
  // (owner request; pauses off-screen, replay restarts)
  (function () {
    var root = document.getElementById("confyroDemo");
    if (!root) return;
    var visible = false, cycles = 0;   // peripheral motion stops after 2 runs
    var q = function (sel) { return root.querySelector(sel); };
    var fly = q("[data-fly]"), src = q("[data-src]"), drop = q("[data-drop]"),
        zone = q("[data-zone]"), check = q("[data-check]"),
        results = q("[data-results]"), statusText = q("[data-status]"), dot = q("[data-dot]");
    var rows = results ? results.querySelectorAll("[data-row]") : [];
    var timers = [], EASE = "cubic-bezier(.2,.7,.2,1)";
    var setStatus = function (t, busy) {
      if (statusText) statusText.textContent = t;
      if (dot) dot.classList.toggle("busy", !!busy);
    };
    var play = function () {
      if (reduced || !fly || !results) return;
      timers.forEach(clearTimeout); timers = [];
      [fly, zone, check, results, src].forEach(function (el) {
        if (el && el.getAnimations) el.getAnimations().forEach(function (a) { a.cancel(); });
      });
      rows.forEach(function (r) { r.style.opacity = "0"; r.style.transform = "translateY(8px)"; });
      fly.style.opacity = "0"; zone.style.opacity = "1"; check.style.opacity = "0";
      results.style.opacity = "0"; src.style.opacity = "1";
      setStatus("Opening SOW-7.docx…", true);
      var dx = 240, dy = -20;
      if (src && drop && fly.offsetParent) {
        var pr = fly.offsetParent.getBoundingClientRect(),
            sr = src.getBoundingClientRect(), dr = drop.getBoundingClientRect();
        fly.style.left = (sr.left - pr.left) + "px"; fly.style.top = (sr.top - pr.top) + "px";
        dx = (dr.left + dr.width / 2) - (sr.left + sr.width / 2) - fly.offsetWidth / 2 + sr.width / 2;
        dy = (dr.top + dr.height / 2) - (sr.top + sr.height / 2);
      }
      src.animate([{ opacity: 1 }, { opacity: 0.32 }],
        { duration: 320, delay: 300, easing: EASE, fill: "forwards" });
      fly.animate([
        { opacity: 0, transform: "translate(0,0) scale(.9)" },
        { opacity: 1, transform: "translate(0,0) scale(1.06)", offset: 0.14 },
        { opacity: 1, transform: "translate(" + (dx * 0.5) + "px," + (dy * 0.5 - 30) + "px) scale(1)", offset: 0.55 },
        { opacity: 1, transform: "translate(" + dx + "px," + dy + "px) scale(.82)", offset: 0.92 },
        { opacity: 0, transform: "translate(" + dx + "px," + dy + "px) scale(.7)" }
      ], { duration: 1000, delay: 200, easing: EASE, fill: "forwards" });
      zone.animate([{ opacity: 1 }, { opacity: 0 }],
        { duration: 260, delay: 1080, easing: EASE, fill: "forwards" });
      check.animate([{ opacity: 0, transform: "scale(.96)" }, { opacity: 1, transform: "scale(1)" }],
        { duration: 320, delay: 1120, easing: EASE, fill: "forwards" });
      timers.push(window.setTimeout(function () { setStatus("Checking 19 claims…", true); }, 1420));
      check.animate([{ opacity: 1 }, { opacity: 0 }],
        { duration: 300, delay: 3120, easing: EASE, fill: "forwards" });
      results.animate([{ opacity: 0, transform: "translateY(12px)" }, { opacity: 1, transform: "none" }],
        { duration: 420, delay: 3180, easing: EASE, fill: "forwards" });
      rows.forEach(function (r, idx) {
        r.animate([{ opacity: 0, transform: "translateY(8px)" }, { opacity: 1, transform: "none" }],
          { duration: 380, delay: 3340 + idx * 100, easing: EASE, fill: "forwards" });
      });
      timers.push(window.setTimeout(function () { setStatus("Report ready · 2 conflicts", false); }, 3900));
      cycles += 1;
      if (cycles < 2) {
        timers.push(window.setTimeout(function () { if (visible) play(); }, 7800));
      }
    };
    var cdReplay = q("[data-cdreplay]");
    if (cdReplay) cdReplay.addEventListener("click", function () { cycles = 0; play(); });
    if (!reduced && "IntersectionObserver" in window) {
      var dio = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          var was = visible;
          visible = entry.isIntersecting;
          if (visible && !was) play();
        });
      }, { threshold: 0.25 });
      dio.observe(root);
    }
  })();

  document.querySelectorAll(".js-only").forEach(function (el) { el.hidden = false; });

  // findings jump to their highlight — delegated, so tab swaps keep working
  document.addEventListener("click", function (event) {
    var card = event.target.closest ? event.target.closest(".rp-card[data-hl]") : null;
    if (!card) return;
    var hl = document.getElementById(card.getAttribute("data-hl"));
    if (!hl) return;
    hl.scrollIntoView({ block: "center", behavior: reduced ? "auto" : "smooth" });
    hl.classList.remove("lit");
    void hl.offsetWidth;
    hl.classList.add("lit");
  });

  // demo tabs: swap document, findings, filename and count in place
  var doc = document.getElementById("rp-doc");
  var findings = document.getElementById("rp-findings");
  var fileLabel = document.getElementById("rp-file");
  var countLabel = document.getElementById("rp-count");
  var body = doc ? doc.closest(".rp-body") : null;
  var tabs = Array.prototype.slice.call(
    document.querySelectorAll(".demotabs button[data-demo]"));
  if (doc && findings && tabs.length) {
    var fixtures = {
      contract: {
        file: fileLabel ? fileLabel.textContent : "",
        count: countLabel ? countLabel.textContent : "",
        doc: doc.innerHTML,
        findings: findings.innerHTML
      }
    };
    document.querySelectorAll("template[data-demo]").forEach(function (tpl) {
      fixtures[tpl.getAttribute("data-demo")] = {
        file: tpl.getAttribute("data-file"),
        count: tpl.getAttribute("data-count") || "",
        doc: tpl.content.querySelector(".t-doc").innerHTML,
        findings: tpl.content.querySelector(".t-findings").innerHTML
      };
    });
    tabs.forEach(function (tab) {
      // counts live on the buttons for the non-contract fixtures
      var fx = fixtures[tab.getAttribute("data-demo")];
      if (fx && !fx.count) fx.count = tab.getAttribute("data-count") || "";
    });
    var select = function (tab) {
      var fx = fixtures[tab.getAttribute("data-demo")];
      if (!fx) return;
      tabs.forEach(function (t) {
        t.setAttribute("aria-selected", t === tab ? "true" : "false");
      });
      var apply = function () {
        doc.innerHTML = fx.doc;
        findings.innerHTML = fx.findings;
        if (fileLabel) fileLabel.textContent = fx.file;
        if (countLabel) countLabel.textContent = fx.count;
        if (body) body.classList.remove("rp-swap");
      };
      if (reduced || !body) { apply(); return; }
      body.classList.add("rp-swap");
      window.setTimeout(apply, 150);
    };
    tabs.forEach(function (tab, i) {
      tab.addEventListener("click", function () { select(tab); });
      tab.addEventListener("keydown", function (event) {
        var d = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
        if (!d) return;
        event.preventDefault();
        var next = tabs[(i + d + tabs.length) % tabs.length];
        next.focus();
        select(next);
      });
    });
  }

})();

/* ============================================================================
   CONFYRO — "Live verification" section  ·  JS BLOCK
   Append inside the existing IIFE in assets/site.js (or paste as its own
   IIFE at the end of the file). No dependencies, ES5, ~55 lines.

   Drives two attributes on .lv-stage; all visuals live in CSS:
     data-step  1..6  — which pipeline stage the scroll has reached
     data-focus -1..2 — which exhibit is currently leading

   Without JS, or under reduced motion, or below 901px, the markup already
   carries the completed state and this never runs.
============================================================================ */

(function () {
  var stage = document.querySelector(".lv-stage");
  var runway = document.querySelector(".lv-runway");
  if (!stage || !runway) return;

  var CLASSES = ["s-claims", "s-refs", "s-eval", "s-validate", "s-report"];
  var reduced =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function complete() {
    for (var i = 0; i < CLASSES.length; i++) stage.classList.add(CLASSES[i]);
    stage.setAttribute("data-step", "6");
    stage.setAttribute("data-focus", "-1");
  }

  // desktop only: the sticky sequence needs room and a pointer-ish viewport
  function active() {
    return !reduced && window.innerWidth > 900;
  }

  var lastStep = -1;
  var lastFocus = "x";
  var ticking = false;

  function update() {
    ticking = false;
    if (!active()) return;

    var total = runway.offsetHeight - window.innerHeight;
    if (total <= 0) return;
    var p = -runway.getBoundingClientRect().top / total;
    if (p < 0) p = 0;
    if (p > 1) p = 1;

    var step = Math.floor(p * 6) + 1;
    if (step > 6) step = 6;
    if (step !== lastStep) {
      lastStep = step;
      for (var i = 0; i < CLASSES.length; i++) stage.classList.remove(CLASSES[i]);
      for (var j = 0; j < step - 1; j++) stage.classList.add(CLASSES[j]);
      stage.setAttribute("data-step", String(step));
    }

    // second half of the runway walks the three exhibits, one at a time
    var focus = -1;
    if (p > 0.5) {
      focus = Math.floor((p - 0.5) / 0.166);
      if (focus > 2) focus = 2;
    }
    if (String(focus) !== lastFocus) {
      lastFocus = String(focus);
      stage.setAttribute("data-focus", lastFocus);
    }
  }

  function onScroll() {
    if (!ticking) {
      ticking = true;
      window.requestAnimationFrame(update);
    }
  }

  function start() {
    if (!active()) {
      complete();
      return;
    }
    // take over from the resolved markup and rewind to the first stage
    for (var i = 0; i < CLASSES.length; i++) stage.classList.remove(CLASSES[i]);
    stage.setAttribute("data-step", "1");
    stage.setAttribute("data-focus", "-1");
    lastStep = -1;
    lastFocus = "x";
    update();
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", start, { passive: true });
  start();
  // claim <-> finding: hover, focus or tap links the pair (28 lines, no deps)
  (function () {
    var scope = document.querySelector(".lv-stage");
    if (!scope) return;
    var pairs = scope.querySelectorAll("[data-ex]");
    var link = function (ex, on) {
      pairs.forEach(function (el) {
        if (el.getAttribute("data-ex") === ex) el.classList.toggle("lv-linked", on);
      });
    };
    pairs.forEach(function (el) {
      var ex = el.getAttribute("data-ex");
      el.addEventListener("mouseenter", function () { link(ex, true); });
      el.addEventListener("mouseleave", function () { link(ex, false); });
      el.addEventListener("focus", function () { link(ex, true); });
      el.addEventListener("blur", function () { link(ex, false); });
      el.addEventListener("click", function () {
        var on = !el.classList.contains("lv-linked");
        pairs.forEach(function (o) { o.classList.remove("lv-linked"); });
        link(ex, on);
      });
      el.addEventListener("keydown", function (e) {
        if (e.key !== "Enter" && e.key !== " ") return;
        e.preventDefault(); el.click();
      });
    });
  })();

})();

/* ============================================================================
   N°03 trust architecture: scroll-synced gate highlight. Self-contained IIFE,
   no deps. Drives one attribute (data-active on .ta-stage) + a few classes;
   all visuals live in CSS. Inert without JS, under reduced motion, or <=760px.
============================================================================ */
(function () {
  var sec = document.getElementById("constitution");
  if (!sec) return;
  var stage = sec.querySelector(".ta-stage");
  var runway = sec.querySelector(".ta-runway");
  var gates = sec.querySelectorAll(".gaterail .gate");
  var glabels = sec.querySelectorAll(".gaterail text");
  var clauses = sec.querySelectorAll(".clause");
  var fill = sec.querySelector(".ta-fill");
  if (!stage || !runway || gates.length !== 4 || clauses.length !== 4) return;

  var GATEX = [236, 526, 816, 1106], L0 = 20, L1 = 1180;
  var reduced = window.matchMedia
    && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var last = -2, ticking = false;

  function active() { return !reduced && window.innerWidth > 760; }

  function apply(i) {
    if (i === last) return;
    last = i;
    stage.setAttribute("data-active", String(i));
    for (var g = 0; g < gates.length; g++) {
      gates[g].classList.toggle("ta-on", g === i);
      gates[g].classList.toggle("ta-passed", g < i);
      if (glabels[g]) glabels[g].classList.toggle("ta-on", g === i);
    }
    for (var c = 0; c < clauses.length; c++) {
      clauses[c].classList.toggle("ta-on", c === i);
    }
    if (fill && i >= 0) {
      var frac = (GATEX[i] - L0) / (L1 - L0);
      fill.style.strokeDashoffset = String(1200 - 1200 * frac);
    }
  }

  function reset() {
    last = -2;
    stage.setAttribute("data-active", "all");
    for (var g = 0; g < gates.length; g++) {
      gates[g].classList.remove("ta-on", "ta-passed");
      if (glabels[g]) glabels[g].classList.remove("ta-on");
    }
    for (var c = 0; c < clauses.length; c++) clauses[c].classList.remove("ta-on");
    if (fill) fill.style.strokeDashoffset = "1200";
  }

  function measure() {
    if (!active()) return;
    var total = runway.offsetHeight - window.innerHeight;
    if (total <= 0) return;
    var p = -runway.getBoundingClientRect().top / total;
    if (p < 0) p = 0;
    if (p > 0.9999) p = 0.9999;
    apply(Math.min(3, Math.floor(p * 4)));
  }

  function onScroll() {
    if (!ticking) {
      ticking = true;
      window.requestAnimationFrame(function () { ticking = false; measure(); });
    }
  }
  function start() { if (!active()) { reset(); } else { last = -2; measure(); } }

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", start, { passive: true });
  start();
})();
