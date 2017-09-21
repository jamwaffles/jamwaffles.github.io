---
layout: post
title:  "Logging analytics events in a testable way with React and Redux"
date:   2017-09-21 10:36:15
categories: web,javascript
image: logging-header.jpg
---

One of my main responsibilites at [TotallyMoney](https://www.totallymoney.com/) was to take care of the in-house analytics/event logging framework. Like lots of companies, understanding what users do and how they interact with a site is an important thing to get good insight on, so people reinvent the wheel with various [krimskrams](https://en.wiktionary.org/wiki/krimskrams) attached, me being no exception. What I want to show in this post is how to integrate an event logging framework into a React/Redux application in a way that's scaleable and reasonably easily unit tested.

