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
  var revealed = document.querySelectorAll(".rv");
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

  // the hero evidence card performs shortly after load
  var herodoc = document.getElementById("herodoc");
  if (herodoc) {
    if (reduced) {
      herodoc.classList.add("live");
    } else {
      window.setTimeout(function () { herodoc.classList.add("live"); }, 350);
    }
  }

  // Exhibit A performs when it scrolls into view (it lives below the fold)
  var perform = document.getElementById("perform");
  if (perform) {
    if (reduced || !("IntersectionObserver" in window)) {
      perform.classList.add("live");
    } else {
      var pio = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          perform.classList.add("live");
          pio.disconnect();
        });
      }, { threshold: 0.3 });
      pio.observe(perform);
    }
  }

  // the report demo is functional: a finding jumps to its highlight
  document.querySelectorAll(".js-only").forEach(function (el) { el.hidden = false; });
  document.querySelectorAll(".rp-card[data-hl]").forEach(function (card) {
    card.addEventListener("click", function () {
      var hl = document.getElementById(card.getAttribute("data-hl"));
      if (!hl) return;
      hl.scrollIntoView({ block: "center", behavior: reduced ? "auto" : "smooth" });
      hl.classList.remove("lit");
      void hl.offsetWidth;
      hl.classList.add("lit");
    });
  });

  // replay buttons re-run their stage's keyframes
  document.querySelectorAll("[data-replay]").forEach(function (btn) {
    if (reduced) return;
    btn.addEventListener("click", function () {
      var stage = document.getElementById(btn.getAttribute("data-replay"));
      if (!stage) return;
      stage.querySelectorAll(".u, .finding, .receipt").forEach(function (el) {
        el.style.animation = "none";
        void el.offsetWidth;
        el.style.animation = "";
      });
    });
  });
})();
