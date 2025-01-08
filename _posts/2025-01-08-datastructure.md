---
title: 数据结构与算法整理
date: 2025-01-08 10:12:00 +0800
categories: [数据结构与算法]
tags: [数据结构与算法]
---

掌握了数据结构与算法，看待问题的深度，解决问题的角度就会完全不一样。因为这样的你，就像是站在巨人的肩膀上，拿着生存利器行走世界。数据结构与算法，会为你的编程之路，甚至人生之路打开一扇通往新世界的大门。
学习算法与数据结构对我们的帮助：

- 建立时间复杂度、空间复杂度意识
- 写出高质量的代码
- 能够设计基础架构
- 提升编程技能
- 训练逻辑思维。

### 复杂度分析

- [复杂度分析](https://jasonbourne723.github.io/posts/complexity/)

## 数据结构

### 数组

数组是一种线性表数据结构，它用一段连续内存空间，来存储一组具有相同类型的数据。对于数组的定义有几个关键点：线性表，连续内存空间，相同类型数据。

- 线性表，顾名思义，就是数据像一条线一样串联的数据结构，结构中的每条数据最多只有前后两个方向，链表/栈/队列都属于线性表数据结构。而树/图等数据结构因为数据不是简单的前后关系，所以不属于线性表结构。
- 连续内存空间和相同类型数据则是数组最重要的特征，它帮助我们提升了根据数组下标随机访问数据的速度。可以直接通过寻址公式(arry[i]_address=baseAddress+i*typeSize)访问数组下标所在位置的数据。但有利也有弊，这个特征让数组的插入和删除操作变得非常低效，比如想在数组中插入或者删除一个数据，为了保证数据连续性，就需要做大量的数据搬移工作。

#### 时间复杂度

- 随机插入数据的时间复杂度：假设要在n长度的数组中第k位插入一条数据，需要将数据插入到第k位置，并将第k位原来的数据向后迁移，这样第k-n位的数据都要向后移动一位。当在数组的末尾插入一条数据时，因为不需要数据移动，所以它的时间复杂度是O(1)，而在数组的开头插入数据时，则是所有的数据都需要向后挪动一位，所以它的时间复杂度是O(n)，因为我们在每个位置插入数据的概率是一样的，所以平均情况的时间复杂度是(1+2+3+...+n)/n=O(n)。

- 删除数据与插入数据的操作类似，所以它们的时间复杂度相同，但是在一些特殊场景下，我们并不一定非要追求数组中数据的连续性，当要删除数据时，我们仅将要删除的数据标记为已删除，但不挪动位置，当数组内存空间不足时，我们再触发一次删除操作(将标记已删除数据删除)，这样就大大减少了删除操作导致的数据搬移(JVM 标记清除垃圾回收算法的核心思想)。

- 查询数据的时间复杂度：分为两种情况，第一种是根据数组下标查询数据，因为我们根据寻址公式可以计算出数组下标数据的内存地址，所以时间复杂度为O(1)。第二种情况是根据数据内容查询，这种情况下，如果数组是有序的，通过二分查找时间复杂度是O(logn)，如果数组是无序的，只能通过遍历，那么查询的时间复杂度就是O(n)。

#### 访问越界 
　　在C语言中，只要不是访问受限的内存，所有的内存空间都是可以自由访问的，如果数组下标越界，就会访问到不属于数组的内存空间上的数据，这样可能会导致严重的系统错误。而在高级语言中，当数组下标越界时，也会在运行时抛出数组下标访问越界的异常，可能使程序进入不可用的状态。所以我们需要格外注意可能造成数组下标访问越界的场景，例如for循环。

#### 反转数组
```go
func reverse(a []int) []int {

	if len(a) == 0 || len(a) == 1 {
		return a
	}
	for i := 0; i < len(a)/2; i++ {
		a[i], a[len(a)-i-1] = a[len(a)-i-1], a[i]
	}
	return a
}
```
### 链表



链表由一系列结点（链表中每一个元素称为结点）组成，结点可以在运行时动态生成。每个结点包括两个部分：一个是存储数据元素的数据域，另一个是存储下一个结点地址的指针域。链表是一种物理存储单元上非连续、非顺序的存储结构，数据元素的逻辑顺序是通过链表中的指针链接次序实现的。

链表和数组一样，作为最底层的数据结构，是很多其他数据结构的底层实现，比如可以用链表来实现队列、栈等等。相比数组对连续内存空间的要求限制，链表对内存的使用就更加灵活，它不需要一块连续的内存空间，而是通过指针将一组零散的内存块串联起来。

![链表](/assets/img/link-list/001.png)

#### 复杂度分析

- 查询：需要遍历链表，时间复杂度为O(n)
- 删除：因为删除数据前需要遍历链表找到要删除的节点，所以时间复杂度同样为O(n),单纯的删除操作为O(1)
- 插入节点：插入到链尾的时间复杂度为O(1)

#### 常见的链表结构

最常见的三种链表结构分别是：单链表，双向链表，循环链表。

##### 单链表

链表通过指针将一组零散的内存块串联在一起，其中每一个内存块就是链表中的一个节点（node），为了所有节点串联起来，节点中不仅要存储数据（data），还需要存储指向下一个节点地址的指针（*next）。结构如下图：
![单链表](/assets/img/link-list/002.png)

我们习惯把第一个节点成为头节点，最后一个节点称为尾节点。尾节点的next指向null，这样我们就可以通过头节点遍历整条链表，直到尾节点的next为null结束。有序链表代码实现如下：

```go
type LinkList struct {
	head *LinkNode
}

type LinkNode struct {
	data int
	next *LinkNode
}

func (l *LinkList) Insert(data int) {

	if l.head == nil {
		l.head = &LinkNode{
			data: data,
			next: nil,
		}
		return
	}
	t := l.head
	priv := l.head
	i := 0
	for t != nil {
		if i == 0 {
			if data < t.data {
				node := &LinkNode{
					data: data,
					next: t,
				}
				l.head = node
				return
			}
		}
		if data < t.data {
			t2 := priv.next
			priv.next = &LinkNode{
				data: data,
				next: t2,
			}
			return
		}
		priv = t
		t = t.next
		i++
	}
	priv.next = &LinkNode{
		data: data,
		next: nil,
	}
}

func (l *LinkList) Print() {
	n := l.head
	for n != nil {
		fmt.Printf("n.data: %v\n", n.data)
		n = n.next
	}
}
```

##### 双向链表

双向链表同样是单链表的变式，区别是节点中不仅要存储next指针，还需要存储一个指向上一个节点的指针（*prev），这样就可以实现链表的双向遍历，提高了链表操作的灵活性。
![双向链表](/assets/img/link-list/004.png)

代码实现如下：

```
type LinkList struct {
	head *LinkNode
	tail *LinkNode
}

type LinkNode struct {
	data int
	next *LinkNode
	priv *LinkNode
}

func (l *LinkList) Insert(data int) {

	if l.head == nil {
		l.head = &LinkNode{
			data: data,
			next: nil,
			priv: nil,
		}
		l.tail = l.head
		return
	}
	t := l.head
	i := 0
	for t != nil {
		if i == 0 {
			if data < t.data {
				node := &LinkNode{
					data: data,
					next: t,
					priv: nil,
				}
				l.head.priv = node
				l.head = node
				return
			}
		}
		if data < t.data {
			node := &LinkNode{
				data: data,
				next: t,
				priv: t.priv,
			}
			t.priv.next = node
			t.priv = node
			return
		}
		t = t.next
		i++
	}
	node := &LinkNode{
		data: data,
		next: nil,
		priv: l.tail,
	}
	l.tail.next = node
	l.tail = node
}

func (l *LinkList) Print() {
	n := l.head
	for n != nil {
		fmt.Printf("n.data: %v\n", n.data)
		n = n.next
	}
}

func (l *LinkList) ReversePrint() {
	n := l.tail
	for n != nil {
		fmt.Printf("n.data: %v\n", n.data)
		n = n.priv
	}
}
```

##### 循环链表

循环链表是单链表的一种变式，唯一的区别就是：尾节点的next不在指向null，而是指向头节点的地址。这样链表就变成了一个环形结构，它的优点就是从链尾到链头比较方便，适合处理具有环形结构特点的数据，比如约瑟夫环问题。
![循环链表](/assets/img/link-list/003.png)


#### 基于链表实现 LRU 缓存淘汰算法

思路是这样的：我们维护一个有序单链表，越靠近链表尾部的结点是越早之前访问的。当有一个新的数据被访问时，我们从链表头开始顺序遍历链表。

- 如果此数据之前已经被缓存在链表中了，我们遍历得到这个数据对应的结点，并将其从原来的位置删除，然后再插入到链表的头部。
- 如果此数据没有在缓存链表中，又可以分为两种情况：
  1. 如果此时缓存未满，则将此结点直接插入到链表的头部；
  2. 如果此时缓存已满，则链表尾结点删除，将新的数据结点插入链表的头部。

这样我们就用链表实现了一个 LRU 缓存，现在我们来看下缓存访问的时间复杂度是多少。因为不管缓存有没有满，我们都需要遍历一遍链表，所以这种基于链表的实现思路，缓存访问的时间复杂度为 O(n)。实际上，我们可以继续优化这个实现思路，比如引入散列表（Hash table）来记录每个数据的位置，将缓存访问的时间复杂度降到 O(1)。这部分的实现我计划在散列表中给出代码实现。

#### 链表使用中的一些技巧

1. 函数中需要移动链表时，最好新建一个指针来移动，以免更改原始指针位置。
2. 链表中找环的思想：创建两个指针一个快指针一次走两步一个慢指针一次走一步，若相遇则有环，若先指向null指针则无环。
3. 链表中找中间节点思想：创建两个指针一个快指针一次走两步一个慢指针一次走一步，快指针到链尾时，慢指针刚好在中间节点位置。
4. 链表找倒数第k个节点思想：创建两个指针，第一个先走k-1步然后两个在一同走。第一个走到最后时则第二个指针指向倒数第k位置。
5. 反向链表思想：从前往后将每个节点的指针反向，即.next内的地址换成前一个节点的，但为了防止后面链表的丢失，在每次换之前需要先创建个指针指向下一个节点。

### 栈

栈是一种操作受限的线性表数据结构，仅允许在一端插入或删除数据。栈中的数据后进者先出。

栈既可以用数组来实现，也可以用链表来实现。用数组实现的栈，我们叫作顺序栈，用链表实现的栈，我们叫作链式栈。如下是顺序栈的代码实现：

```
// 基于数组实现的顺序栈
public class ArrayStack {
  private String[] items;  // 数组
  private int count;       // 栈中元素个数
  private int n;           //栈的大小

  // 初始化数组，申请一个大小为n的数组空间
  public ArrayStack(int n) {
    this.items = new String[n];
    this.n = n;
    this.count = 0;
  }
  // 入栈操作
  public boolean push(String item) {
    // 数组空间不够了，直接返回false，入栈失败。
    if (count == n) return false;
    // 将item放到下标为count的位置，并且count加一
    items[count] = item;
    ++count;
    return true;
  }
  // 出栈操作
  public String pop() {
    // 栈为空，则直接返回null
    if (count == 0) return null;
    // 返回下标为count-1的数组元素，并且栈中元素个数count减一
    String tmp = items[count-1];
    --count;
    return tmp;
  }
}
```

#### 栈的应用

##### 栈在函数调用中的应用

操作系统给每个线程分配了一块独立的内存空间，这块内存被组织成“栈”这种结构，用来存储函数调用时的临时变量。每进入一个函数，就会将其中的临时变量作为栈帧入栈，当被调用函数执行完成，返回之后，将这个函数对应的栈帧出栈。

##### 栈在表达式求值中的应用

例如：求表达式`34+13*9+44-12/3`的值，利用两个栈，其中一个用来保存操作数，另一个用来保存运算符。我们从左向右遍历表达式，当遇到数字，我们就直接压入操作数栈；当遇到运算符，就与运算符栈的栈顶元素进行比较，若比运算符栈顶元素优先级高，就将当前运算符压入栈，若比运算符栈顶元素的优先级低或者相同，从运算符栈中取出栈顶运算符，从操作数栈顶取出2个操作数，然后进行计算，把计算完的结果压入操作数栈，继续比较。

##### 栈在括号匹配中的应用

用栈保存为匹配的左括号，从左到右一次扫描字符串，当扫描到左括号时，则将其压入栈中；当扫描到右括号时，从栈顶取出一个左括号，如果能匹配上，则继续扫描剩下的字符串。如果扫描过程中，遇到不能配对的右括号，或者栈中没有数据，则说明为非法格式。
当所有的括号都扫描完成之后，如果栈为空，则说明字符串为合法格式；否则，说明未匹配的左括号为非法格式。

##### 如何实现浏览器的前进后退功能

我们使用两个栈X和Y，我们把首次浏览的页面依次压如栈X，当点击后退按钮时，再依次从栈X中出栈，并将出栈的数据一次放入Y栈。当点击前进按钮时，我们依次从栈Y中取出数据，放入栈X中。当栈X中没有数据时，说明没有页面可以继续后退浏览了。当Y栈没有数据，那就说明没有页面可以点击前进浏览了。

### 队列

队列是一种操作受限的线性表数据结构，它的特点是只允许在表的前端进行删除操作，而在表的后端进行插入操作。即先进者先出。队列只支持两个基础操作，入队 enqueue()，放一个数据到队列尾部；出队 dequeue()，从队列头部取一个元素。

#### 顺序队列和链式队列

队列可以用数组来实现，也可以用链表来实现。用数组实现的队列叫作顺序队列，用链表实现的队列叫作链式队列。
用数组实现队列需要两个指针，head指针，指向队头；tail指针，指向队尾。在入队/出队时,通过调整head/tail指针的指向就可以实现一个先进先出的队列。代码实现如下：

```c#
// 用数组实现的队列
public class ArrayQueue {
  // 数组：items，数组大小：n
  private String[] items;
  private int n = 0;
  // head表示队头下标，tail表示队尾下标
  private int head = 0;
  private int tail = 0;

  // 申请一个大小为capacity的数组
  public ArrayQueue(int capacity) {
    items = new String[capacity];
    n = capacity;
  }

  // 入队
  public boolean enqueue(String item) {
    // 如果tail == n 表示队列已经满了
    if (tail == n) return false;
    items[tail] = item;
    ++tail;
    return true;
  }

  // 出队
  public String dequeue() {
    // 如果head == tail 表示队列为空
    if (head == tail) return null;
    String ret = items[head];
    ++head;
    return ret;
  }
}
```
但上段代码也存在一个问题，随着不停地进行入队、出队操作，head 和 tail 都会持续往后移动。当 tail 移动到最右边，即使数组中还有空闲空间，也无法继续往队列中添加数据了。为了解决这个问题，我们可以在入队方法中，增加数据搬移的逻辑：
```c#
  public boolean enqueue(String item) {
    // tail == n表示队列末尾没有空间了
    if (tail == n) {
      // tail ==n && head==0，表示整个队列都占满了
      if (head == 0) return false;
      // 数据搬移
      for (int i = head; i < tail; ++i) {
        items[i-head] = items[i];
      }
      // 搬移完之后重新更新head和tail
      tail -= head;
      head = 0;
    }
    items[tail] = item;
    ++tail;
    return true;
  }
```
基于链表实现方式如下图：
![基于链表实现方式](/assets/img/queue/001.png)

#### 循环队列

虽然数据搬移解决了顺序队列的空间浪费问题，但是也影响了enqueue()最差情况时间复杂度。那么有没有什么办法可以避免就行数据迁移呢？答案是有的，我们可以通过循环队列来解决这个问题

![循环队列](/assets/img/queue/002.png)

循环队列不再是一条有头有尾的直线，而是首尾相连的圆环。它的实现也比较简单，关键的是，确定好队空和队满的判定条件。循环队列队空的判断条件是 head == tail，队满的判断条件(tail+1)%n=head。代码实现如下：

```c#
public class CircularQueue {
  // 数组：items，数组大小：n
  private String[] items;
  private int n = 0;
  // head表示队头下标，tail表示队尾下标
  private int head = 0;
  private int tail = 0;

  // 申请一个大小为capacity的数组
  public CircularQueue(int capacity) {
    items = new String[capacity];
    n = capacity;
  }

  // 入队
  public boolean enqueue(String item) {
    // 队列满了
    if ((tail + 1) % n == head) return false;
    items[tail] = item;
    tail = (tail + 1) % n;
    return true;
  }

  // 出队
  public String dequeue() {
    // 如果head == tail 表示队列为空
    if (head == tail) return null;
    String ret = items[head];
    head = (head + 1) % n;
    return ret;
  }
}
```

#### 阻塞队列和并发队列

- 阻塞队列其实就是在队列基础上增加了阻塞操作。简单来说，就是在队列为空的时候，从队头取数据会被阻塞。因为此时还没有数据可取，直到队列中有了数据才能返回；如果队列已经满了，那么插入数据的操作就会被阻塞，直到队列中有空闲位置后再插入数据，然后再返回。
- 并发队列即线程安全的队列。最简单直接的实现方式是直接在 enqueue()、dequeue() 方法上加锁，但是锁粒度大并发度会比较低，同一时刻仅允许一个存或者取操作。实际上，基于数组的循环队列，利用 CAS 原子操作，可以实现非常高效的并发队列。这也是循环队列比链式队列应用更加广泛的原因。

#### 线程池中的应用

线程池没有空闲线程时，新的任务请求线程资源时，线程池该如何处理呢？一般有两种处理策略。第一种是非阻塞的处理方式，直接拒绝任务请求；另一种是阻塞的处理方式，将请求排队，等到有空闲线程时，取出排队的请求继续处理。

1. 基于链表的实现方式，可以实现一个支持无限排队的无界队列（unbounded queue），但是可能会导致过多的请求排队等待，请求处理的响应时间过长。所以，针对响应时间比较敏感的系统，基于链表实现的无限排队的线程池是不合适的。
2. 基于数组实现的有界队列（bounded queue），队列的大小有限，所以线程池中排队的请求超过队列大小时，接下来的请求就会被拒绝，这种方式对响应时间敏感的系统来说，就相对更加合理。不过，设置一个合理的队列大小，也是非常有讲究的。队列太大导致等待的请求太多，队列太小会导致无法充分利用系统资源、发挥最大性能。

### 散列表

散列表（hash table），又名‘hash表’，它用的是数组支持按照下标随机访问数据（时间复杂度O(1)）的特性，所以散列表其实就是基于数组结构的一种扩展。

简单的来说，就是把键值通过散列函数求得hash值之后，对数组容量进行取模运算，得到存放在数组位置的下标值，当我们按照键值查询元素时，我们用同样的方法将键值转化数组下标，从对应的数组下标的位置取数据。

散列表这种数据结构虽然支持非常高效的数据插入、删除、查找操作，但是散列表中的数据都是通过散列函数打乱之后无规律存储的。也就说，它无法支持按照某种顺序快速地遍历数据。如果希望按照顺序遍历散列表中的数据，那我们需要将散列表中的数据拷贝到数组中，然后排序，再遍历。因为散列表是动态数据结构，不停地有数据的插入、删除，所以每当我们希望按顺序遍历散列表中的数据的时候，都需要先排序，那效率势必会很低。为了解决这个问题，我们常常会将散列表和链表（或者跳表）结合在一起使用

#### 散列函数

散列函数，顾名思义，它是一个函数。我们可以把它定义成 hash(key)，其中 key 表示元素的键值，hash(key) 的值表示经过散列函数计算得到的散列值。设计散列函数的三个基本要求：

1. 散列函数计算得到的散列值是一个非负整数；
2. 如果 key1 = key2，那 hash(key1) == hash(key2)；
3. 如果 key1 ≠ key2，那 hash(key1) ≠ hash(key2)。（这一点几乎不可能做到，所以散列冲突也是散列表必须考虑的问题。）

散列函数的好坏，决定了散列冲突的概率大小，也决定了散列表的性能。一个好的散列函数应该具备以下条件：

1. 不能太复杂，散列函数设计的太复杂，势必会增加计算时间，进而影响散列表的性能。
2. 散列函数生成的值要尽可能随机并均匀分布，这样才能尽量避免或最小化散列冲突，防止出现某个槽内数据特别多的情况。

#### 冲突处理

再好的散列函数也无法避免散列冲突。那究竟该如何解决散列冲突问题呢？我们常用的散列冲突解决方法有两类，开放寻址法（open addressing）和链表法（chaining）。

##### 开放寻址法

开放寻址法的核心思想是，如果出现了散列冲突，我们就重新探测一个空闲位置，将其插入。例如当我们往散列表中插入数据时，如果某个数据经过散列函数散列之后，存储位置已经被占用了，我们就从当前位置开始，依次往后查找，看是否有空闲位置，直到找到为止。在查找数据时，我们通过散列函数求出要查找元素的键值对应的散列值，然后比较数组中下标为散列值的元素和要查找的元素。如果相等，则说明就是我们要找的元素；否则就顺序往后依次查找。如果遍历到数组中的空闲位置，还没有找到，就说明要查找的元素并没有在散列表中。因为查找数据时需要根据空闲位置判断数据是否存在，所以在删除数据时，不能直接将位置设置为空，而要采用设置删除标志位的方式。这种方法称为线性探测法，还有另外两种比较经典的探测方法，二次探测（Quadratic probing）和双重散列（Double hashing）。所谓二次探测，跟线性探测很像，线性探测每次探测的步长是 1，那它探测的下标序列就是 hash(key)+0，hash(key)+1，hash(key)+2……而二次探测探测的步长就变成了原来的“二次方”，也就是说，它探测的下标序列就是 hash(key)+0，hash(key)+12，hash(key)+22……所谓双重散列，意思就是不仅要使用一个散列函数。我们使用一组散列函数 hash1(key)，hash2(key)，hash3(key)……我们先用第一个散列函数，如果计算得到的存储位置已经被占用，再用第二个散列函数，依次类推，直到找到空闲的存储位置。线性探测的简单代码实现如下：
```c#
public class HashMap<T>
{
    private int _capacity;
    private readonly double _loadFactor;
    private int _count;
    private Node<T>[] _array;
    private object _lock = new object();
    private IEqualityComparer<string> comparer = EqualityComparer<string>.Default;
    public HashMap(int capacity = 8, double loadFactor = 0.75)
    {
        _capacity = capacity;
        _loadFactor = loadFactor;
        _array = new Node<T>[capacity];
    }
    //获取数组下标
    private int GetIndex(string key, Node<T>[] array)
    {
        var hashKey = comparer.GetHashCode(key) & 0x7FFFFFFF;
        var index = hashKey % _capacity;
        while (array[index] != null)
        {
            if (array[index].key == key)
                break;
            index = index == _capacity - 1 ? 0 : index + 1;
        }
        return index;
    }
    //动态扩容
    private void Dilatation()
    {
        var currLoadFactor = ((double)_count) / _capacity;
        if (currLoadFactor > _loadFactor)
        {
            _capacity *= 2;
            var array = new Node<T>[_capacity];
            foreach (var item in _array)
            {
                if (item != null)
                {
                    Set(item.key, item.value, array);
                }
            }
            _array = array;
        }
    }
    private void Set(string key, T value, Node<T>[] array)
    {
        var index = GetIndex(key, array);
        array[index] = new Node<T>()
        {
            key = key,
            value = value
        };
    }
    public void Set(string key, T value)
    {
        lock (_lock)
        {
            Dilatation();
            Set(key, value, _array);
            _count++;
        }
    }
    public bool Get(string key, out T value)
    {
        lock (_lock)
        {
            int index = GetIndex(key, _array);
            var node = _array[index];
            if (node == null)
            {
                value = default(T);
                return false;
            }
            else
            {
                value = node.value;
                return true;
            }
        }
    }
    class Node<T>
    {
        public string key { get; set; }

        public T value { get; set; }
    }
}
```

##### 链表法

链表法是一种更加常用的散列冲突解决办法，相比开放寻址法，它要简单很多。我们来看这个图，在散列表中，每个“桶（bucket）”或者“槽（slot）”会对应一条链表，所有散列值相同的元素我们都放到相同槽位对应的链表中。当插入的时候，我们只需要通过散列函数计算出对应的散列槽位，将其插入到对应链表中即可，所以插入的时间复杂度是 O(1)。当查找、删除一个元素时，我们同样通过散列函数计算出对应的槽，然后遍历链表查找或者删除。
![链表法](/assets/img/hashtable/001.png)
简易代码实现如下：
```
public class LinkedHashMap<T> : IHashMap<T>
{
    private int _capacity;
    private readonly double _loadFactor;
    private IEqualityComparer<string> comparer = EqualityComparer<string>.Default;
    private LinkList<Node<T>>[] _array;
    private int _count = 0;
    public LinkedHashMap(int capacity = 8, double loadFactor = 0.75)
    {
        _capacity = capacity;
        _loadFactor = loadFactor;
        _array = new LinkList<Node<T>>[_capacity];
    }
    private int GetIndex(string key)
    {
        var hashKey = comparer.GetHashCode(key) & 0x7FFFFFFF;
        var index = hashKey % _capacity;
        return index;
    }
    //动态扩容
    private void Dilatation()
    {
        var currLoadFactor = ((double)_count) / _capacity;
        if (currLoadFactor > _loadFactor)
        {
            _capacity *= 2;
            var array = new LinkList<Node<T>>[_capacity];
            _count = 0;
            foreach (var item in _array)
            {
                if (item != null)
                {
                    var node = item.First();
                    while (node != null)
                    {
                        Set(node.data.key, node.data.value, array);
                        node = node.next;
                    }
                }
            }
            _array = array;
        }
    }
    private void Set(string key, T value, LinkList<Node<T>>[] array)
    {
        var index = GetIndex(key);
        if (array[index] == null)
        {
            var linkList = new LinkList<Node<T>>();
            linkList.Insert(new Node<T>()
            {
                key = key,
                value = value
            });
            array[index] = linkList;
        }
        else
        {
            array[index].Insert(new Node<T>()
            {
                key = key,
                value = value
            });
        }
        _count++;
    }
    public bool Get(string key, out T value)
    {
        var index = GetIndex(key);
        if (_array[index] == null)
        {
            value = default(T);
            return false;
        }
        else
        {
            var node = _array[index].First();
            while (node != null)
            {
                if (node.data.key == key)
                {
                    value = node.data.value;
                    return true;
                }
                else
                {
                    node = node.next;
                }
            }
            value = default(T);
            return false;
        }
    }
    public void Set(string key, T value)
    {
        Dilatation();
        Set(key, value, _array);
    }
    class Node<T>
    {
        public string key { get; set; }
        public T value { get; set; }
    }
}
```

#### 装载因子

装载因子的计算公式： 

```
散列表的装载因子=填入表中的元素个数/散列表的长度 
```

可以看出装载因子越大，说明表中的元素个数越多，冲突越多，散列表的性能会下降。当超过一定的阈值时，散列表的时间复杂度可能会降低到O(n)，这是让人无法让人接受的，但我们可以通过动态扩容的方式解决这个问题。当装载因子过大时，重新申请一个更大的散列表，将数据搬移到这个新散列表中。假设每次扩容我们都申请一个原来散列表大小两倍的空间。如果原来散列表的装载因子是 0.8，那经过扩容之后，新散列表的装载因子就下降为原来的一半，变成了 0.4。针对散列表的扩容，数据搬移操作相对复杂一些。因为散列表的大小变了，数据的存储位置也变了，所以我们需要通过散列函数重新计算每个数据的存储位置。

上述方案存在一个问题，当散列表进行扩容时，由于需要进行数据迁移，所以本次插入会变得很慢，针对这个问题，我们可以选择惰性迁移的方式，当装载因子超过阈值时，重新申请一个更大的散列表，但是不进行全部的数据迁移，而是将一小部分数据进行迁移，后面每次插入新数据时，再逐次一小部分的进行迁移，直至将旧的散列表搬空。对于查询操作，为了兼容了新、老散列表中的数据，我们先从新散列表中查找，如果没有找到，再去老的散列表中查找即可。

#### 散列表的应用

##### Word 文档中单词拼写检查功能是如何实现的？

常用的英文单词有 20 万个左右，假设单词的平均长度是 10 个字母，平均一个单词占用 10 个字节的内存空间，那 20 万英文单词大约占 2MB 的存储空间，就算放大 10 倍也就是 20MB。对于现在的计算机来说，这个大小完全可以放在内存里面。所以我们可以用散列表来存储整个英文单词词典。当用户输入某个英文单词时，我们拿用户输入的单词去散列表中查找。如果查到，则说明拼写正确；如果没有查到，则说明拼写可能有误，给予提示。借助散列表这种数据结构，我们就可以轻松实现快速判断是否存在拼写错误。

##### LRU 缓存淘汰算法

借助散列表，我们可以把 LRU 缓存淘汰算法的时间复杂度降低为 O(1)。首先，我们需要维护一个按照访问时间从大到小有序排列的链表结构。因为缓存大小有限，当缓存空间不够，需要淘汰一个数据的时候，我们就直接将链表头部的结点删除。当要缓存某个数据的时候，先在链表中查找这个数据。如果没有找到，则直接将数据放到链表的尾部；如果找到了，我们就把它移动到链表的尾部。因为查找数据需要遍历链表，所以单纯用链表实现的 LRU 缓存淘汰算法的时间复杂很高，是 O(n)。一个缓存（cache）系统主要包含下面这几个操作：往缓存中添加一个数据、从缓存中删除一个数据、在缓存中查找一个数据。如果我们将散列表和链表两种数据结构组合使用，可以将这三个操作的时间复杂度都降低到 O(1)。

1. 查找数据：通过散列表，我们可以很快地在缓存中找到一个数据。当找到数据之后，我们还需要将它移动到双向链表的尾部。
2. 删除数据：我们需要找到数据所在的结点，然后将结点删除。借助散列表，我们可以在 O(1) 时间复杂度里找到要删除的结点。因为我们的链表是双向链表，双向链表可以通过前驱指针 O(1) 时间复杂度获取前驱结点，所以在双向链表中，删除结点只需要 O(1) 的时间复杂度
3. 添加数据：添加数据到缓存稍微有点麻烦，我们需要先看这个数据是否已经在缓存中。如果已经在其中，需要将其移动到双向链表的尾部；如果不在其中，还要看缓存有没有满。如果满了，则将双向链表头部的结点删除，然后再将数据放到链表的尾部；如果没有满，就直接将数据放到链表的尾部。

具体结构如下：
![lru](/assets/img/hashtable/002.png)
简易代码实现如下：
```c#
public class LruLinkList<T>
{
    private Node<T> _head;
    private Node<T> _tail;
    private int _capacity;
    private HashTable _hashTable;
    private int _count = 0;
    public LruLinkList(int capacity = 8)
    {
        _capacity = capacity;
        _hashTable = new HashTable(capacity);
    }
    public void Set(string key, T value)
    {
        if (_hashTable.Get(key, out var existNode))
        {
            existNode.value = value;
            LruMove(existNode);
        }
        else
        {
            if (_count == _capacity)
            {
                _hashTable.Delete(_head.key);
                _head = _head.next;
                _head.prev = null;
                _count--;
            }
            if (_head == null)
            {
                _head = new Node<T>();
                _head.key = key;
                _head.value = value;
                _tail = _head;
                _hashTable.Set(key, _head);
            }
            else
            {
                var node = new Node<T>();
                node.key = key;
                node.value = value;
                _tail.next = node;
                node.prev = _tail;
                _tail = node;
                _hashTable.Set(key, node);
            }
            _count++;
        }
    }
    public bool Get(string key, out T value)
    {
        if (_hashTable.Get(key, out var node))
        {
            LruMove(node);
            value = node.value;
            return true;
        }
        else
        {
            value = default(T);
            return false;
        }
    }
    private void LruMove(Node<T> node)
    {
        if (node.key != _tail.key)
        {
            if (node.key == _head.key)
            {
                node.next.prev = null;
                _head = node.next;
                MoveToTail(node);
            }
            else
            {
                node.prev.next = node.next;
                node.next.prev = node.prev;
                MoveToTail(node);
            }
        }
    }
    private void MoveToTail(Node<T> node)
    {
        node.prev = _tail;
        node.next = null;
        _tail.next = node;
        _tail = node;
    }
    public List<T> FindAll()
    {
        var list = new List<T>();
        var node = _head;
        while (node != null)
        {
            list.Add(node.value);
            node = node.next;
        }
        return list;
    }
    public class Node<T>
    {
        public string key { get; set; }
        public T value { get; set; }
        public Node<T> next { get; set; }
        public Node<T> prev { get; set; }
        public Node<T> hnext { get; set; }
    }
    public class HashTable
    {
        private HashNode[] array;
        private IEqualityComparer<string> comparer = EqualityComparer<string>.Default;
        private int _capacity;
        public HashTable(int capacity)
        {
            array = new HashNode[capacity];
            _capacity = capacity;
        }
        public bool Get(string key, out Node<T> value)
        {
            var index = GetIndex(key);
            if (array[index] != null)
            {
                var tempNode = array[index].node;
                while (tempNode != null)
                {
                    if (tempNode.key == key)
                    {
                        value = tempNode;
                        return true;
                    }
                    tempNode = tempNode.hnext;
                }
            }
            value = default(Node<T>);
            return false;
        }
        public void Set(string key, Node<T> node)
        {
            var index = GetIndex(key);
            if (array[index] != null)
            {
                var tempNode = array[index].node;
                while (tempNode.hnext != null)
                {
                    tempNode = tempNode.hnext;
                }
                tempNode.hnext = node;
            }
            else
            {
                array[index] = new HashNode()
                {
                    key = key,
                    node = node
                };
            }
        }
        public void Delete(string key)
        {
            var index = GetIndex(key);
            if (array[index] != null)
            {
                var tempNode = array[index].node;
                var isFirst = true;
                Node<T> lastNode = null;
                while (tempNode != null)
                {
                    if (tempNode.key == key)
                    {
                        if (isFirst)
                        {
                            if (tempNode.hnext != null)
                            {
                                array[index].key = tempNode.hnext.key;
                                array[index].node = tempNode.hnext;
                            }
                            else
                            {
                                array[index] = null;
                            }
                        }
                        else
                        {
                            lastNode.hnext = tempNode.hnext;
                        }
                        return;
                    }
                    isFirst= false;
                    lastNode = tempNode;
                    tempNode = tempNode.hnext;
                }
            }
        }
        private int GetIndex(string key)
        {
            var hashKey = comparer.GetHashCode(key) & 0x7FFFFFFF;
            return hashKey % _capacity;
        }
        public class HashNode
        {
            public string key { get; set; }
            public Node<T> node { get; set; }
        }
    }
}
```

### 树

树是一种非线性表结构，它是由n(n≥0)个有限节点组成一个具有层次关系的集合。把它叫做“树”是因为它看起来像一棵倒挂的树，也就是说它是根朝上，而叶朝下的。它具有以下的特点：每个节点有零个或多个子节点；没有父节点的节点称为根节点；每一个非根节点有且只有一个父节点；除了根节点外，每个子节点可以分为多个不相交的子树。

![](/assets/img/binary-tree/001.png)

#### 树的各种概念

如下图，A 节点就是 B 节点的父节点，B 节点是 A 节点的子节点。B、C、D 这三个节点的父节点是同一个节点，所以它们之间互称为兄弟节点。我们把没有父节点的节点叫做根节点，也就是图中的节点 E。我们把没有子节点的节点叫做叶子节点或者叶节点，比如图中的 G、H、I、J、K、L 都是叶子节点。

![](/assets/img/binary-tree/002.png)

- 节点的高度：节点到叶子节点的最长路径（边数）
- 节点的深度：根节点到这个节点所经历的边的个数
- 节点的层数：节点的深度+1
- 树的高度：根节点的高度

![](/assets/img/binary-tree/003.png)

### 二叉树

二叉树，顾名思义，每个节点最多有两个“叉”，也就是两个子节点，分别是左子节点和右子节点。除了叶子节点之外，每个节点都有左右两个子节点，这种二叉树就叫做满二叉树。叶子节点都在最底下两层，最后一层的叶子节点都靠左排列，并且除了最后一层，其他层的节点个数都要达到最大，这种二叉树叫做完全二叉树。

#### 如何存储一颗二叉树

##### 链式存储法

一种基于指针或者引用的二叉链式存储法，每个节点有三个字段，其中一个存储数据，另外两个是指向左右子节点的指针。我们只要拎住根节点，就可以通过左右子节点的指针，把整棵树都串起来。这种存储方式我们比较常用。大部分二叉树代码都是通过这种结构来实现的。结构如下图：

![](/assets/img/binary-tree/004.png)

##### 顺序存储法

我们把根节点存储在下标 i = 1 的位置，那左子节点存储在下标 2 * i = 2 的位置，右子节点存储在 2 * i + 1 = 3 的位置。以此类推，B 节点的左子节点存储在 2 * i = 2 * 2 = 4 的位置，右子节点存储在 2 * i + 1 = 2 * 2 + 1 = 5 的位置。即如果节点 X 存储在数组中下标为 i 的位置，下标为 2 * i 的位置存储的就是左子节点，下标为 2 * i + 1 的位置存储的就是右子节点。

![](/assets/img/binary-tree/006.png)

不过上图是一颗完全二叉树，所以数组仅仅浪费了下标为0的存储位置，如果是非完全二叉树，则可能会浪费比较多的数组内存空间。所以当要存储的树是一颗完全二叉树时，数组才是最合适的选择。

#### 二叉树的遍历

常用的二叉树的遍历有三种方法，前序遍历、中序遍历和后序遍历。

![](/assets/img/binary-tree/007.png)

实际上，二叉树的前、中、后序遍历就是一个递归的过程。

```
前序遍历的递推公式：
preOrder(r) = print r->preOrder(r->left)->preOrder(r->right)
中序遍历的递推公式：
inOrder(r) = inOrder(r->left)->print r->inOrder(r->right)
后序遍历的递推公式：
postOrder(r) = postOrder(r->left)->postOrder(r->right)->print r
```

二叉树遍历的伪代码实现：

```c#
void preOrder(Node* root) {
  if (root == null) return;
  print root // 此处为伪代码，表示打印root节点
  preOrder(root->left);
  preOrder(root->right);
}

void inOrder(Node* root) {
  if (root == null) return;
  inOrder(root->left);
  print root // 此处为伪代码，表示打印root节点
  inOrder(root->right);
}

void postOrder(Node* root) {
  if (root == null) return;
  postOrder(root->left);
  postOrder(root->right);
  print root // 此处为伪代码，表示打印root节点
}
```

#### 二叉查找树

二叉查找树是二叉树中最常用的一种类型，也叫二叉搜索树，它最大的特点就是，支持动态数据集合的快速插入、删除、查找操作。二叉查找树要求，在树中的任意一个节点，其左子树中的每个节点的值，都要小于这个节点的值，而右子树节点的值都大于这个节点的值。简易代码实现如下：

```c#
 public class LinkBinaryTree
 {
        private Node _root;
        public LinkBinaryTree()
        {
        }
        public void insert(int data)
        {
            if (_root == default(Node))
            {
                _root = new Node(data);
                return;
            }
            var node = _root;
            while (node != null)
            {
                if (data < node.data)
                {
                    if (node.left == null)
                    {
                        node.left = new Node(data);
                        return;
                    }
                    node = node.left;
                }
                else
                {
                    if (node.Right == null)
                    {
                        node.Right = new Node(data);
                        return;
                    }
                    node = node.Right;
                }
            }
        }
        public bool Exist(int data)
        {
            if (_root == default(Node)) return false;
            var node = _root;
            while (node != null)
            {
                if (node.data == data)
                {
                    return true;
                }
                else if (node.data < data)
                {
                    node = node.Right;
                }
                else
                {
                    node = node.left;
                }
            }
            return false;
        }
        public void Delete(int data)
        {
            if (_root == default(Node)) return;
            var node = _root;
            Node pNode = null;
            while (node != null && node.data != data)
            {
                pNode = node;
                node = node.data > data ? node.left : node.Right;
            }
            if (node == null) return;
            // 要删除的节点有两个子节点
            if (node.left != null && node.Right != null)
            {
                Node minP = node.Right;
                Node minPP = node;
                while (minP.left != null)
                {
                    minPP = minP;
                    minP = minP.left;
                }
                node.data = minP.data;
                node = minP;
                pNode = minPP;

            }
            // 删除节点是叶子节点或者仅有一个子节点
            Node child = null;
            if (node.left != null)
            {
                child = node.left;
            }
            else if (node.Right != null)
            {
                child = node.Right;
            }
            if (pNode == null)
            {
                _root = child;
            }
            else if (pNode.left == node)
            {
                pNode.left = child;
            }
            else
            {
                pNode.Right = child;
            }
        }
        public void Print()
        {
            if (_root == default(Node)) return;
            MiddlePrint(_root);
        }
        private void MiddlePrint(Node node)
        {
            if (node.left != null)
            {
                MiddlePrint(node.left);
            }
            Console.WriteLine($"{node.data}");
            if (node.Right != null)
            {
                MiddlePrint(node.Right);
            }
        }
        class Node
        {
            public Node(int data)
            {
                this.data = data;
            }
            public Node(int data, Node left, Node right)
            {
                this.data = data;
                this.left = left;
                Right = right;
            }
            public int data { get; set; }
            public Node left { get; set; }
            public Node Right { get; set; }
        }
}
```

##### 二叉查找树的时间复杂度分析

实际上，二叉查找树的形态各式各样。比如这个图中，对于同一组数据，我们构造了三种二叉查找树。它们的查找、插入、删除操作的执行效率都是不一样的。图中第一种二叉查找树，根节点的左右子树极度不平衡，已经退化成了链表，所以查找的时间复杂度就变成了 O(n)。

![](/assets/img/binary-tree/008.png)

可以看出，不管操作是插入、删除还是查找，时间复杂度其实都跟树的高度成正比，也就是 O(height)。树的高度就等于最大层数减一，为了方便计算，我们转换成层来表示。包含 n 个节点的满二叉树中，第一层包含 1 个节点，第二层包含 2 个节点，第三层包含 4 个节点，依次类推，下面一层节点个数是上一层的 2 倍，第 K 层包含的节点个数就是 2^(K-1)。不过，对于完全二叉树来说，最后一层的节点个数有点儿不遵守上面的规律了。它包含的节点个数在 1 个到 2^(L-1) 个之间（我们假设最大层数是 L）。如果我们把每一层的节点个数加起来就是总的节点个数 n。也就是说，如果节点的个数是 n，那么 n 满足这样一个关系：

```
n >= 1+2+4+8+...+2^(L-2)+1
n <= 1+2+4+8+...+2^(L-2)+2^(L-1)
```

借助等比数列的求和公式，我们可以计算出，L 的范围是[log2(n+1), log2n +1]。完全二叉树的层数小于等于 log2n +1，也就是说，完全二叉树的高度小于等于 log2n。因此平衡二叉查找树（在任何时候，都能保持任意节点左右子树都比较平衡的二叉查找树）的高度接近 logn，所以插入、删除、查找操作的时间复杂度也比较稳定，是 O(logn)。

##### 二叉查找树相比散列表的优势

1. 散列表中的数据是无序存储的，如果要输出有序的数据，需要先进行排序。而对于二叉查找树来说，我们只需要中序遍历，就可以在 O(n) 的时间复杂度内，输出有序的数据序列。
2. 散列表扩容耗时很多，而且当遇到散列冲突时，性能不稳定，尽管二叉查找树的性能不稳定，但是在工程中，我们最常用的平衡二叉查找树的性能非常稳定，时间复杂度稳定在 O(logn)。
3. 笼统地来说，尽管散列表的查找等操作的时间复杂度是常量级的，但因为哈希冲突的存在，这个常量不一定比 logn 小，所以实际的查找速度可能不一定比 O(logn) 快。加上哈希函数的耗时，也不一定就比平衡二叉查找树的效率高。
4. 散列表的构造比二叉查找树要复杂，需要考虑的东西很多。比如散列函数的设计、冲突解决办法、扩容、缩容等。平衡二叉查找树只需要考虑平衡性这一个问题，而且这个问题的解决方案比较成熟、固定。
5. 为了避免过多的散列冲突，散列表装载因子不能太大，特别是基于开放寻址法解决冲突的散列表，不然会浪费一定的存储空间。

### AVL树

AVL 树是计算机科学中最早被发明的自平衡二叉查找树。在 AVL 树中，任一节点对应的两棵子树的最大高度差为1，因此它也被称为高度平衡树。查找、插入和删除在平均和最坏情况下的时间复杂度都是 O(logn),增加和删除元素的操作则可能需要借由一次或多次树旋转，以实现树的重新平衡。

假设平衡因子是左子树的高度减去右子树的高度所得到的值，又假设由于在二叉排序树上插入节点而失去平衡的最小子树根节点的指针为a（即a是离插入点最近，且平衡因子绝对值超过1的祖先节点），则失去平衡后进行的规律可归纳为下列四种情况：

- 单向右旋平衡处理LL：由于在*a的左子树根节点的左子树上插入节点，*a的平衡因子由1增至2，致使以*a为根的子树失去平衡，则需进行一次右旋转操作；
- 单向左旋平衡处理RR：由于在*a的右子树根节点的右子树上插入节点，*a的平衡因子由-1变为-2，致使以*a为根的子树失去平衡，则需进行一次左旋转操作；
- 双向旋转（先左后右）平衡处理LR：由于在*a的左子树根节点的右子树上插入节点，*a的平衡因子由1增至2，致使以*a为根的子树失去平衡，则需进行两次旋转（先左旋后右旋）操作。
- 双向旋转（先右后左）平衡处理RL：由于在*a的右子树根节点的左子树上插入节点，*a的平衡因子由-1变为-2，致使以*a为根的子树失去平衡，则需进行两次旋转（先右旋后左旋）操作。

代码如下：
```go
func NewBinaryTree() *BinaryTree {
	tree := new(BinaryTree)
	return tree
}

type BinaryTree struct {
	root *Node
}

type Node struct {
	item   int
	count  int
	left   *Node
	right  *Node
	height int8
}

func GetHeight(node *Node) int8 {
	if node == nil {
		return -1
	}
	return node.height
}

func (b *BinaryTree) Insert(item int) {
	b.root = insert(b.root, item)
}

func insert(node *Node, item int) *Node {
	if node == nil {
		return &Node{
			item:   item,
			count:  1,
			height: 0,
		}
	}
	if item > node.item {
		node.right = insert(node.right, item)
		if GetHeight(node.right)-GetHeight(node.left) > 1 {
			if item > node.right.item {
				node = singleRotateRight(node)
			} else {
				node = doubleRotateRight(node)
			}
		}
	} else if item < node.item {
		node.left = insert(node.left, item)
		if GetHeight(node.left)-GetHeight(node.right) > 1 {
			if item > node.left.item {
				node = doubleRotateLeft(node)
			} else {
				node = singleRotateLeft(node)
			}
		}
	} else {
		node.count++
	}
	node.height = maxInt8(GetHeight(node.left), GetHeight(node.right)) + 1
	return node
}

func maxInt8(a, b int8) int8 {
	if a > b {
		return a
	}
	return b
}

func singleRotateLeft(n *Node) *Node {
	n1 := n.left
	n.left = n1.right
	n1.right = n
	n1.height = maxInt8(GetHeight(n1.left), GetHeight(n1.right)) + 1
	n.height = maxInt8(GetHeight(n.left), GetHeight(n.right)) + 1
	return n1
}

func singleRotateRight(n *Node) *Node {
	n1 := n.right
	n.right = n1.left
	n1.left = n
	n1.height = maxInt8(GetHeight(n1.left), GetHeight(n1.right)) + 1
	n.height = maxInt8(GetHeight(n.left), GetHeight(n.right)) + 1
	return n1
}

func doubleRotateLeft(n *Node) *Node {

	n.left = singleRotateRight(n.left)
	return singleRotateLeft(n)
}

func doubleRotateRight(n *Node) *Node {
	n.right = singleRotateLeft(n.right)
	return singleRotateRight(n)
}
```

### B+树

引用过去的文章 [B+树](https://jasonbourne723.github.io/posts/b+tree/)

### 堆

### 不相交集合（Disjoint set）

### 图

### 跳表

### 红黑树

## 过去的文章

- [数组](https://jasonbourne723.github.io/posts/array/)
- [链表](https://jasonbourne723.github.io/posts/link-list/)
- [栈](https://jasonbourne723.github.io/posts/stack/)
- [散列表](https://jasonbourne723.github.io/posts/hash-table/)
- [队列](https://jasonbourne723.github.io/posts/queue/)
- [二叉树](https://jasonbourne723.github.io/posts/binary-tree/)
- [堆](https://jasonbourne723.github.io/posts/heap/)
- [trie树](https://jasonbourne723.github.io/posts/trie/)
- [图](https://jasonbourne723.github.io/posts/graph/)
- [跳表](https://jasonbourne723.github.io/posts/skip-list/)
- [B+树](https://jasonbourne723.github.io/posts/b+tree/)
- [位图](https://jasonbourne723.github.io/posts/bit-map/)
- [红黑树](https://jasonbourne723.github.io/posts/red-black-tree/)

### 算法

- [递归](https://jasonbourne723.github.io/posts/recursion/)
- [二分查找](https://jasonbourne723.github.io/posts/binary-search/)
- [BF/RK字符串匹配算法](https://jasonbourne723.github.io/posts/bf-rk/)
- [深度广度优先搜索](https://jasonbourne723.github.io/posts/deep-search/)
- [拓扑排序，Dijkstra，A*算法](https://jasonbourne723.github.io/posts/dijkstra/)
- [四种算法思想](https://jasonbourne723.github.io/posts/algorithm-thinking/)
- [BM，kmp，ac自动机](https://jasonbourne723.github.io/posts/bm-kmp/)
