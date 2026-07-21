/* ============================================================
   Confyro — cinematic hero intro
   ------------------------------------------------------------
   Drives the cover's dive-into-the-laptop on scroll, hands off to a
   gentle auto-run, blooms to white, then reveals the real hero beneath.
   Only ever touches .ci-* elements. Returns immediately unless html.ci-on
   is set — the inline <head> gate adds that class only when JS is on and
   prefers-reduced-motion is off, so no-JS / reduced-motion never reach
   here and the site renders untouched.
   Ported 1:1 from ~/confyro-hero-lab/index.html (owner-approved constants).
============================================================ */
(function () {
  var root = document.documentElement;
  if (!root.classList.contains("ci-on")) return;          // enhancement only
  // The inline gate armed a fallback that strips ci-on if we never run; we did.
  if (window.__ciFallback) { clearTimeout(window.__ciFallback); window.__ciFallback = 0; }

  var cover = document.getElementById("ci-cover"),
      diver = document.getElementById("ci-diver"),
      flash = document.getElementById("ci-flash"),
      cue   = document.getElementById("ci-cue");
  if (!cover || !diver || !flash) { root.classList.remove("ci-on"); return; }

  /* site.css sets html{scroll-behavior:smooth}; the auto-run's per-frame
     scrollTo needs 'auto'. Scope the override to the auto-run only, so the
     nav's smooth anchor-scrolling stays intact the rest of the time. */
  var prevSB = root.style.scrollBehavior;
  function setAutoSB() { root.style.scrollBehavior = "auto"; }
  function restoreSB() { root.style.scrollBehavior = prevSB || ""; }

  function play() {
    diver.classList.remove("ci-playing");
    void diver.offsetWidth;                                // restart the entrance
    diver.classList.add("ci-playing");
  }
  requestAnimationFrame(play);

  var MAXS = 18, ticking = false;
  /* THRESH: a tiny scroll nudge from the poster hands off to the auto-run. */
  var THRESH = 0.05, armed = false, autoRAF = 0;
  function clamp(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

  function stopAuto() { if (autoRAF) { cancelAnimationFrame(autoRAF); autoRAF = 0; restoreSB(); } }
  function autoTo(targetY) {
    stopAuto(); setAutoSB();
    var startY = window.scrollY, dist = targetY - startY, t0 = null, dur = 2600;
    function step(ts) {
      if (t0 === null) t0 = ts;
      var k = Math.min(1, (ts - t0) / dur);
      var e = k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;   // easeInOutCubic
      window.scrollTo(0, startY + dist * e);
      if (k < 1) { autoRAF = requestAnimationFrame(step); } else { autoRAF = 0; restoreSB(); }
    }
    autoRAF = requestAnimationFrame(step);
  }

  function apply() {
    ticking = false;
    var len = window.innerHeight * 1.6;
    var p = clamp(window.scrollY / len);

    var s = 1 + (MAXS - 1) * Math.pow(p, 1.7);             // dive into the screen
    diver.style.transform = "scale(" + s.toFixed(3) + ")";

    var textFade = (1 - clamp(p / 0.26)).toFixed(3);       // poster text fades early
    var top = diver.querySelector(".ci-top"), bot = diver.querySelector(".ci-bottom");
    if (top) top.style.opacity = textFade;
    if (bot) bot.style.opacity = textFade;

    /* the white bloom: brightens AND keeps growing, holds full-white for a beat */
    flash.style.opacity = clamp((p - 0.30) / 0.22).toFixed(3);
    var bloom = (0.55 + clamp((p - 0.30) / 0.50) * 1.55).toFixed(3);
    flash.style.transform = "scale(" + bloom + ")";

    /* reveal the real hero only after the long, big white hold */
    var cov = 1 - clamp((p - 0.82) / 0.16);
    cover.style.opacity = cov.toFixed(3);
    cover.style.pointerEvents = cov < 0.02 ? "none" : "auto";
    if (cue) cue.style.opacity = (1 - clamp(p / 0.10)).toFixed(3);

    /* hand-off: a small scroll kicks off the whole run automatically */
    if (!armed && p >= THRESH && p < 0.9) { armed = true; autoTo(len + 2); }
    if (p < 0.02 && !autoRAF) { armed = false; }           // back at the very top → re-arm
  }
  function onScroll() { if (!ticking) { ticking = true; requestAnimationFrame(apply); } }
  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll, { passive: true });
  /* let the visitor bail out of the auto-run by scrolling back up */
  window.addEventListener("wheel", function (e) { if (autoRAF && e.deltaY < 0) stopAuto(); }, { passive: true });
  window.addEventListener("touchmove", function () { if (autoRAF) stopAuto(); }, { passive: true });
  apply();
})();
