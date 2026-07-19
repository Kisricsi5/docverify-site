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
    var onScroll = function () {
      topbar.classList.toggle("scrolled", window.scrollY > 8);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  // scroll reveals — content is visible without JS; this only choreographs it
  var revealed = document.querySelectorAll(".rv, .rvh, .gaterail, .finline");
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
    var visible = false;
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
      timers.push(window.setTimeout(function () { if (visible) play(); }, 7800));
    };
    var cdReplay = q("[data-cdreplay]");
    if (cdReplay) cdReplay.addEventListener("click", play);
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

  // Exhibit A: plays once as it enters — underline, arrow, source, stamp.
  // Arrow endpoints are measured from the real layout so they always hit
  // claim -> source -> finding.
  var exwrap = document.getElementById("exwrap");
  if (exwrap) {
    var exLayout = function () {
      var svg = exwrap.querySelector(".exline");
      if (!svg) return;
      var host = svg.parentElement, hr = host.getBoundingClientRect();
      if (!hr.width) return;
      svg.setAttribute("viewBox", "0 0 " + Math.round(hr.width) + " " + Math.round(hr.height));
      // arrowhead: triangle with its tip at (x,y), pointing along ang
      var HEAD = 12, HALF = 5.5;
      var headD = function (x, y, ang) {
        var bx = x - Math.cos(ang) * HEAD, by = y - Math.sin(ang) * HEAD;
        var ox = Math.sin(ang) * HALF, oy = -Math.cos(ang) * HALF;
        return "M " + x + " " + y + " L " + (bx + ox) + " " + (by + oy) +
               " L " + (bx - ox) + " " + (by - oy) + " Z";
      };
      var claim = exwrap.querySelector(".exclaim"),
          draftcard = exwrap.querySelector(".exgrid .sheet:not(.exsrc)"),
          srcline = exwrap.querySelector(".exsrcline"),
          srccard = exwrap.querySelector(".exsrc"),
          find = exwrap.querySelector(".exfind .finding");
      var l1 = document.getElementById("exl1"), h1 = document.getElementById("exh1"),
          l2 = document.getElementById("exl2"), h2 = document.getElementById("exh2");
      // arrow 1 lives only BETWEEN the two cards: edge to edge
      if (claim && draftcard && srcline && srccard && l1 && h1) {
        var a = claim.getBoundingClientRect(), dc = draftcard.getBoundingClientRect(),
            b = srcline.getBoundingClientRect(), sc = srccard.getBoundingClientRect();
        var x1 = dc.right - hr.left + 6, y1 = a.top - hr.top + a.height / 2;
        var x2 = sc.left - hr.left - 6, y2 = b.top - hr.top + Math.min(b.height / 2, 12);
        var ang = Math.atan2(y2 - y1, x2 - x1);
        l1.setAttribute("d", "M " + x1 + " " + y1 + " L " +
          (x2 - Math.cos(ang) * (HEAD - 2)) + " " + (y2 - Math.sin(ang) * (HEAD - 2)));
        h1.setAttribute("d", headD(x2, y2, ang));
      }
      // arrow 2 drops from the source card and lands on the report's top edge
      if (srccard && find && l2 && h2) {
        var c = srccard.getBoundingClientRect(), f = find.getBoundingClientRect();
        var sx = c.left - hr.left + c.width / 2, sy = c.bottom - hr.top + 6;
        var ex = f.left - hr.left + f.width / 2, ey = f.top - hr.top - 6;
        var bend = Math.max(44, (ey - sy) * 0.7);
        l2.setAttribute("d", "M " + sx + " " + sy + " C " + sx + " " + (sy + bend) +
          ", " + ex + " " + (ey - bend) + ", " + ex + " " + (ey - (HEAD - 2)));
        h2.setAttribute("d", headD(ex, ey, Math.PI / 2));
      }
    };
    window.addEventListener("resize", exLayout, { passive: true });
    exLayout();
    if (reduced || !("IntersectionObserver" in window)) {
      exwrap.classList.add("s1", "s2", "s3");
    } else {
      var xio = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          xio.disconnect();
          exLayout();
          exwrap.classList.add("s1");
          window.setTimeout(function () { exwrap.classList.add("s2"); }, 650);
          window.setTimeout(function () { exwrap.classList.add("s3"); }, 1650);
        });
      }, { threshold: 0.35 });
      xio.observe(exwrap);
    }
  }

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
