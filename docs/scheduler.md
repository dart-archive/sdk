**class Scheduler**

*Fields*

* `Array Threads` - Non-growable list of `Thread`s.
* `Stack IdleThreads` - List of idle `Thread`s.

```
EnqueueOnThread
```

```
EnqueueOnAnyThread(P) {
  if TryEnqueueOnIdleThread(P): return True
  while True {
    for T in Threads {
      Empty <- T.IsEmpty()
      If T.TryEnqueue(P) {
        if Empty: T.Wakeup(): return False
      }
    }
  }
}
```

```
TryEnqueueOnIdleThread(P) {
  while True {
    T <- IdleThreads.Pop()  # Is really a CAS, linked-list through Threads
    if T = Null: return False
    if !T.TryEnqueue(P): continue
    T.Wakeup()
    return True
  }
}
```

```
TryDequeueFromAnyThread() {
  for each T in Threads {
    Success, P <- T.TryDequeue()
    if P != Null: return P;
  }
  return Null;
}
```

```
DequeueFromThread(T) {
  while True {
    Success, P <- T.TryDequeue()
    if Success: return P
    P <- TryDequeueFromAnyThread()
    if P != Null: return P
  }
}
```

**class Thread**

Each Thread has a queue of scheduled processes, with 3 simple commands:


- `TryEnqueue` - Try to enqueue a Process to the end of the queue.
- `TryDequeue` - Try to dequeue the head element of the queue.
- `TryDequeueEntry` - Try to dequeue a specific P from the queue.

_Fields_

- `Process Head` - Head of queue
- `Process Tail` - Tail/end of queue
- `Process Sentinel` - Non-Null & unique Process value.
- `Monitor IdleMonitor`

_Members_

```
TryEnqueue(P) {
  H <- Head
  while True {
    if H = Sentinel: return False
    if Head.CompareAndSwap(H, Sentinel): break
    H <- Head
  }
  P.OwnerThread <- This
  if H != Null {
    Tail.Next <- P
    P.Previous <- Tail
    Tail <- P
    Head <- H
  } else {
    Tail <- P
    Head <- P
  }
  return True
}
```

```
TryDequeue() {
  H <- Head
  while True {
    if H == Sentinel: return False, Null
    if H == Null: return True, Null
    if Head.CompareAndSwap(H, Sentinel): break
    H <- Head
  }
  if Tail = H: Tail <- Null
  Next <- H.Next
  if next != Null: Next.Previous <- Null
  H.ChangeState(Ready, Running)
  H.Queue <- Null
  H.Next <- Null
  Head = Next;
  return True, H
}
```

```
IsEmpty {
  return Head == Null;
}

```

```
TryDequeueEntry(P)
  TODO(ajohnsen): Add.
```

```
Wakeup() {
  IdleMonitor.Lock();
  IdleMonitor.Notify();
  IdleMonitor.Unlock();
}
```

**class Process**

*Fields*

- `Thread OwnerThread`
- `Process Next`
- `Process Previous`
