---
title: Implementing a Simple Queue in PostgreSQL
summary: In this article I show you how you can implement efficient queue operations using PostgresSQL database. The implementation uses atomic 'test and set' method for popping elements from queue ensuring consistent behaviour.
layout: post
permalink: implementing-queue-in-postgresql
last_modified_at: 2021-09-17
---

It's a common situation when you have to process items stored somewhere using background jobs. I think it is more common when you can't (don't want to) ensure that only one job instance accesses the items at the same time.

A queue is a good data structure that fits for that kind of problem. You can find many good / feature rich queue implemtations ( for example: [Amazon SQS](https://aws.amazon.com/sqs "Amazon Simple Queue Service"){:target="_blank"} )

However it is possible that you don't want to start using a new component to have a simple queue functionality, but you already use a relational database like PostgreSQL. I show you a very simple implementation of queue operations (push, pop) using a relational database. Applying this method your jobs can pop items atomically from the queue so having multiple job instances at the same time shouldn't be a problem.

## Data Structure

The queue storage can be implemented in a single table where we have dedicated columns for the queue functionality and one general column for the payload.

```sql
CREATE TABLE simple_queue
(
    id UUID NOT NULL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    processing_started_at TIMESTAMP,
    errors TEXT,
    payload TEXT
);

CREATE INDEX ix_simple_queue_pop on simple_queue (processing_started_at, created_at ASC)
INCLUDE (id)
WHERE processing_started_at IS NULL;
```

- `errors` : If the processing fails for any reasons, you can store error logs here
- `payload` : You can store any data in textual format, for example as a `JSON`

The `created_at` and `processing_started_at` columns are in the heart of the queue operations, I will describe them later in this article. As you can see there is an index for these columns to ensure the proper performance of the queue operations.

## Push Operation

Adding (pushing) an item to the queue is the simpler part of the queue operations. It requires an `id` generation and it should be persisted alongside with the payload and current timestamp.

```sql
INSERT INTO simple_queue (id, created_at, payload)
VALUES (
    'd6513382-4dcc-4c44-b044-08b98257037c' -- newly generated GUID
    ,'2021-09-07 15:48:38.403' -- the current timestamp in UTC
    ,'I am an awesome payload'
);
```

## Pop Operation using Atomic 'Test and Set'

If you have more than one actor who can pop items from the queue, then we must ensure the consistency of this kind of data access. It means one item can be popped by only one actor.

Popping an item consists of two operations:
- querying the next item which isn't under processing
- indicating the processing of it has been started.

The above operations should be executed as an __atomic__ operation to ensure the consistency.

Using a relational database you can choose from more than one good solutions.
The traditional way is simply encapsulating the querying and setting to a database transaction, but I would like to show you a different solution which uses only one command.

The `update` command can be used with conditions and also can return data. __In this way we can achieve the consistent pop operation implementing an atomic 'test-and-set' in the database.__

```sql
UPDATE simple_queue as sq SET processing_started_at = '2021-09-07 15:52:42.123' -- setting the current timestamp in UTC
WHERE sq.id = (
    SELECT sqInner.id FROM simple_queue sqInner
    WHERE sqInner.processing_started_at IS NULL
    ORDER By sqInner.created_at
	LIMIT 1
    FOR UPDATE
)
RETURNING sq.id, sq.payload -- returning with the stored data (popping)
```

In the above example we use the `processing_started_at` column for checking whether the processing of an item has been started or not and we atomically set the value of the first unprocessed item. 

The above command works well with `READ COMMITTED` isolation level, because it uses the `FOR UPDATE` modifier for the `SELECT` subquery. It ensures that the given row cannot be modified by an `UPDATE` from another transaction. You can read more about it in the [official documentation](https://www.postgresql.org/docs/9.0/sql-select.html#SQL-FOR-UPDATE-SHARE){:target="_blank"}.

You can also use the `FOR UPDATE SKIP LOCKED` modifier instead of the simple `FOR UPDATE` to tune the performance. In that case the given transaction simply skips the rows that are locked by another transaction which is a good solution for a queue data structure. Without the `SKIP LOCKED` modifier the transaction waits until the other transaction finishes the locking.

At this stage you have the item and other job instances cannot access it with this pop method.

## Finalizing the Queue Operation

After popping successfully the item from the queue, usually the given job processes it somehow and it either fails or succeeds.

After successfully processing the item you can simply delete the item from the queue using the `id` that you received with the pop operation.

```sql
DELETE FROM simple_queue
WHERE id = 'd6513382-4dcc-4c44-b044-08b98257037c'
```

### Error Handling

If the item processing fails, the above data structure has the ability to store some information about the error. For example:

```sql
UPDATE simple_queue SET errors = 'Something went wrong'
WHERE id = 'd6513382-4dcc-4c44-b044-08b98257037c'
```

There are cases when the item remains in the queue:

- after executing the above command
- the consumer process ends before either removing the item (success) or saving error info (failure)

There are many good solutions for handling such situations, but I don't cover them in this article.

Keep in mind that these operations don't conflict with the popping operation because the `processing_started_at` value was already set earlier.



## Summary 

We saw how we can implement very simple and consistent queue operations using PostgreSQL. The consistency is ensured by the atomic pop operation. 

__Other Databases__
All code examples above use Postgres dialect of SQL, but the described method can be implemented on all major relational (SQL) databases like SQL Server or MySQL.

I wrote [another post](/implementing-queue-in-sql-server "Implementing a Simpel Queue in SQL Server") which describes how you can implement it in Microsoft SQL Server.
