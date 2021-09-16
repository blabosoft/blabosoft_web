---
title: Implementing a Simple Queue in SQL Server
layout: post
permalink: implementing-queue-in-sql-server
summary: Implementing simple and efficient queue operations in Microsoft SQL Server. The pop operation uses a common table expression (CTE) to implement an atomic 'test and set' method.
---

In my [previous article](/implementing-queue-in-postgresql "Implementing a Simple Queue in PostgreSQL") I described the concepts of how you can implement simple and efficient queue operations using PostgreSQL database engine. 

Now I show you how you can implement the same queue operations on Microsoft SQL Server. The core concept is the same here, it uses atomic 'test and set'  method for the pop operation. Before you continue the reading, I recommend to check the [previous article](/implementing-queue-in-postgresql "Implementing a Simple Queue in PostgreSQL") to read more about the motivation and the concepts.

