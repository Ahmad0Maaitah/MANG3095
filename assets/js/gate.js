/* gate.js - reveals content week by week on a fixed schedule.
   Each week unlocks at 08:00 UK time on its Monday; weeks are one
   calendar week apart. Elements carry data-week="N"; before week N
   unlocks they are hidden and their links disabled.

   To shift the whole term, change TERM_START below (one line).
   (c) Dr Ahmad Maaitah. All rights reserved. */
(function () {
  'use strict';

  /* Week 1, first teaching day. UK is UTC+1 (BST) on 21 Sep 2026.
     Edit this one line to move the whole term. */
  var TERM_START = '2026-09-21T08:00:00+01:00';
  var TZ = 'Europe/London';

  var MS_WEEK = 7 * 24 * 60 * 60 * 1000;
  var start = Date.parse(TERM_START);

  function unlockMs(week) { return start + (week - 1) * MS_WEEK; }

  function fmt(ms) {
    try {
      return new Date(ms).toLocaleString('en-GB', {
        weekday: 'short', day: 'numeric', month: 'short',
        hour: '2-digit', minute: '2-digit', timeZone: TZ
      });
    } catch (e) {
      return new Date(ms).toDateString();
    }
  }

  function apply() {
    var now = Date.now();
    var nodes = document.querySelectorAll('[data-week]');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var wk = parseInt(el.getAttribute('data-week'), 10);
      if (!wk) continue;
      var u = unlockMs(wk);
      el.classList.add('gated');
      if (now >= u) { el.classList.remove('locked'); continue; }
      el.classList.add('locked');
      var links = el.querySelectorAll('a[href]');
      for (var j = 0; j < links.length; j++) {
        links[j].setAttribute('data-locked-href', links[j].getAttribute('href'));
        links[j].removeAttribute('href');
        links[j].setAttribute('aria-disabled', 'true');
        links[j].tabIndex = -1;
      }
      /* Hide the content directly in JS so it works even if a stale
         cached stylesheet is missing the .gated.locked rules. */
      for (var k = 0; k < el.children.length; k++) {
        var child = el.children[k];
        if (!child.classList.contains('keep') && !child.classList.contains('lockbadge')) {
          child.style.display = 'none';
        }
      }
      if (!el.querySelector(':scope > .lockbadge')) {
        var b = document.createElement('div');
        b.className = 'lockbadge';
        b.style.cssText = 'display:flex;align-items:center;gap:.5em;margin-top:8px;' +
          'color:#94a3b8;background:#273449;border:1px dashed #334155;border-radius:12px;' +
          'padding:14px 16px;font-size:.92rem;font-weight:600;';
        b.innerHTML = '🔒 Unlocks ' + fmt(u);
        el.appendChild(b);
      }
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', apply);
  } else {
    apply();
  }
})();
