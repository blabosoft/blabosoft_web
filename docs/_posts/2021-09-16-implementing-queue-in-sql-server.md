---
title: Implementing a Simple Queue in SQL Server
layout: post
permalink: implementing-queue-in-sql-server
summary: Implementing simple and efficient queue operations in Microsoft SQL Server. The pop operation uses a common table expression (CTE) to implement an atomic 'test and set' method.
---

In my [previous article](/implementing-queue-in-postgresql "Implementing a Simple Queue in PostgreSQL") I described the implementation of simple and efficient queue operations using PostgreSQL database engine. 

Now I show you how you can implement the queue operations with the same interface on Microsoft SQL Server. The core concept is similar here, it uses atomic 'test and set'  method for the pop operation. Before you continue reading, I recommend to check the [previous article](/implementing-queue-in-postgresql "Implementing a Simple Queue in PostgreSQL") to read more about the motivation and the concept.

## Data Structure

This implementation uses one table as a storage for the queue.

```sql
CREATE TABLE SimpleQueue
(
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    CreatedAt DATETIME2 NOT NULL,
    ProcessingStartedAt DATETIME2,
    Errors NVARCHAR(MAX),
    Payload NVARCHAR(MAX)
);

CREATE INDEX IX_SIMPLEQUEUE_POP on SimpleQueue (ProcessingStartedAt, CreatedAt ASC)
INCLUDE (Id)
WHERE ProcessingStartedAt IS NULL;
```

- `Payload`: it is the general storage for the queue payload, the data must be in textual format, for example a `JSON` or a Base64-encoded string
- `Errors`: you can store any error log here in case of a processing failure. You can implement any manual/automated solution for error handling, it is one possible solution to leave the items in the queue if the processing failed
- `CreatedAt`: it is used for sorting the items during the pop method and also shows the valuable information about the creation time :) (You can find more details later)
- `ProcessingStartedAt`: it serves as an indicator whether the processing of the item has been started (You can find more details later)

The `IX_SIMPLEQUEUE_POP` is a non-clustered index which is needed for the efficient pop operation.

## Push Operation

The push operation is very simple, we insert a new item to the table.

```sql
INSERT INTO SimpleQueue (Id, CreatedAt, Payload)
VALUES (
    'd6513312-4dcc-4c44-b044-08b98257037c' -- newly generated GUID
    ,'2021-09-16 17:55:38.403' -- the current timestamp in UTC
    ,'I am an awesome payload in MS SQL Server'
);
```

When I published the blog post about the Postgres version of the queue implementation, some people asked why I didn't use the system time of the database for the creation time. The answer is I simply prefer adding the time values from the processing code because in this case I have bigger control. For example: I have a scheduled background job which pops elements from the queue, I query the current timestamp only at the beginning of the processing and use the same value for each pop operation. In this case the timestamp serves as a correlation id as well.

## Pop Operation using Atomic 'Test and Set'

In our case, the pop operation means inidicating the processing of an item has been started. After a successful processing we will remove the item from the table.

To pop an item from the queue we should query the first available item and flagging it that processing has been started. The operation should be atomic to ensure consistency.

In SQL Server we can use common table expressions with update command and it also can return data. Using this toolset we can achive a proper atomic 'test and set' method. Let's see the code itself:

```sql
WITH PoppedItemCte(Id, Payload, ProcessingStartedAt) AS
(
    SELECT TOP(1)
        sq.Id,
        sq.Payload,
        sq.ProcessingStartedAt
    FROM SimpleQueue sq WITH (READPAST, UPDLOCK)
    WHERE sq.ProcessingStartedAt IS NULL
    ORDER BY sq.CreatedAt
)
UPDATE PoppedItemCte SET ProcessingStartedAt = '2021-09-16 18:42:38.403'
OUTPUT inserted.Id, inserted.Payload
```

We use the `ProcessingStartedAt` column as an indicator whether the processing of the given item has been started or not.

You can see the query part contains the `WITH (READPAST, UPDLOCK)` hints. The `UPDLOCK` tells the SQL Server to use update lock for the one queried item. The `READPAST` instructs the query engine to skip the items which are already locked. The latter results a very good performance because there is no waiting for other transactions to be completed.

The usage of these hints ensures atomicity and consistency with good performance. This command works well at `READ COMMITTED` isolation level.

Let's take a look at the execution plan of the above command:

{% include image.html src="/assets/images/posts/pop-cte-with-update.png" alt="CTE with UPDATE plan" title="Execution Plan of the Pop Operation" %}

The query uses the `IX_SIMPLEQUEUE_POP` index for getting the first available item and fortunately there is no nested loop in the plan.


## Finalizing the Queue Operation

If the processing was successful, then you can simply remove the item from the table with the following command:

```sql
DELETE FROM SimpleQueue 
WHERE Id = 'd6513312-4dcc-4c44-b044-08b98257037c'
```

If the processing failed, you can leave the item in the table and also can add some info about the error:

```sql
UPDATE SimpleQueue SET Errors = 'Something went wrong'
WHERE Id = 'd6513312-4dcc-4c44-b044-08b98257037c'
```

The above commands don't conflict with the pop operation because the value of `ProcessingStartedAt` has already been set.

It is also possible that you weren't able to finalize the operation, because the consumer process was killed before it could have made the finall call. There are many manual or automated solutions to address this issue, but I don't cover them in this article.

## Summary

We implemented a simple queue operation where the pop method is atomic and efficient.