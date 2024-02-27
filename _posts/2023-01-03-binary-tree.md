---
title: 数据结构与算法：二叉树
date: 2023-01-03 10:12:00 +0800
categories: [数据结构与算法]
tags: [数据结构与算法]
---

> 树是一种非线性表结构，它是由n(n≥0)个有限节点组成一个具有层次关系的集合。把它叫做“树”是因为它看起来像一棵倒挂的树，也就是说它是根朝上，而叶朝下的。它具有以下的特点：每个节点有零个或多个子节点；没有父节点的节点称为根节点；每一个非根节点有且只有一个父节点；除了根节点外，每个子节点可以分为多个不相交的子树。

![](/assets/img/binary-tree/001.png)

## 树的各种概念

如下图，A 节点就是 B 节点的父节点，B 节点是 A 节点的子节点。B、C、D 这三个节点的父节点是同一个节点，所以它们之间互称为兄弟节点。我们把没有父节点的节点叫做根节点，也就是图中的节点 E。我们把没有子节点的节点叫做叶子节点或者叶节点，比如图中的 G、H、I、J、K、L 都是叶子节点。

![](/assets/img/binary-tree/002.png)

- 节点的高度：节点到叶子节点的最长路径（边数）
- 节点的深度：根节点到这个节点所经历的边的个数
- 节点的层数：节点的深度+1
- 树的高度：根节点的高度

![](/assets/img/binary-tree/003.png)

## 二叉树

二叉树，顾名思义，每个节点最多有两个“叉”，也就是两个子节点，分别是左子节点和右子节点。除了叶子节点之外，每个节点都有左右两个子节点，这种二叉树就叫做满二叉树。叶子节点都在最底下两层，最后一层的叶子节点都靠左排列，并且除了最后一层，其他层的节点个数都要达到最大，这种二叉树叫做完全二叉树。

### 如何存储一颗二叉树

#### 链式存储法

一种基于指针或者引用的二叉链式存储法，每个节点有三个字段，其中一个存储数据，另外两个是指向左右子节点的指针。我们只要拎住根节点，就可以通过左右子节点的指针，把整棵树都串起来。这种存储方式我们比较常用。大部分二叉树代码都是通过这种结构来实现的。结构如下图：

![](/assets/img/binary-tree/004.png)

#### 顺序存储法

我们把根节点存储在下标 i = 1 的位置，那左子节点存储在下标 2 * i = 2 的位置，右子节点存储在 2 * i + 1 = 3 的位置。以此类推，B 节点的左子节点存储在 2 * i = 2 * 2 = 4 的位置，右子节点存储在 2 * i + 1 = 2 * 2 + 1 = 5 的位置。即如果节点 X 存储在数组中下标为 i 的位置，下标为 2 * i 的位置存储的就是左子节点，下标为 2 * i + 1 的位置存储的就是右子节点。

![](/assets/img/binary-tree/006.png)

不过上图是一颗完全二叉树，所以数组仅仅浪费了下标为0的存储位置，如果是非完全二叉树，则可能会浪费比较多的数组内存空间。所以当要存储的树是一颗完全二叉树时，数组才是最合适的选择。

### 二叉树的遍历

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

```
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

## 二叉查找树

二叉查找树是二叉树中最常用的一种类型，也叫二叉搜索树，它最大的特点就是，支持动态数据集合的快速插入、删除、查找操作。二叉查找树要求，在树中的任意一个节点，其左子树中的每个节点的值，都要小于这个节点的值，而右子树节点的值都大于这个节点的值。简易代码实现如下：

```
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

### 二叉查找树的时间复杂度分析

实际上，二叉查找树的形态各式各样。比如这个图中，对于同一组数据，我们构造了三种二叉查找树。它们的查找、插入、删除操作的执行效率都是不一样的。图中第一种二叉查找树，根节点的左右子树极度不平衡，已经退化成了链表，所以查找的时间复杂度就变成了 O(n)。

![](/assets/img/binary-tree/008.png)

可以看出，不管操作是插入、删除还是查找，时间复杂度其实都跟树的高度成正比，也就是 O(height)。树的高度就等于最大层数减一，为了方便计算，我们转换成层来表示。包含 n 个节点的满二叉树中，第一层包含 1 个节点，第二层包含 2 个节点，第三层包含 4 个节点，依次类推，下面一层节点个数是上一层的 2 倍，第 K 层包含的节点个数就是 2^(K-1)。不过，对于完全二叉树来说，最后一层的节点个数有点儿不遵守上面的规律了。它包含的节点个数在 1 个到 2^(L-1) 个之间（我们假设最大层数是 L）。如果我们把每一层的节点个数加起来就是总的节点个数 n。也就是说，如果节点的个数是 n，那么 n 满足这样一个关系：

```
n >= 1+2+4+8+...+2^(L-2)+1
n <= 1+2+4+8+...+2^(L-2)+2^(L-1)
```

借助等比数列的求和公式，我们可以计算出，L 的范围是[log2(n+1), log2n +1]。完全二叉树的层数小于等于 log2n +1，也就是说，完全二叉树的高度小于等于 log2n。因此平衡二叉查找树（在任何时候，都能保持任意节点左右子树都比较平衡的二叉查找树）的高度接近 logn，所以插入、删除、查找操作的时间复杂度也比较稳定，是 O(logn)。

### 二叉查找树相比散列表的优势

1. 散列表中的数据是无序存储的，如果要输出有序的数据，需要先进行排序。而对于二叉查找树来说，我们只需要中序遍历，就可以在 O(n) 的时间复杂度内，输出有序的数据序列。
2. 散列表扩容耗时很多，而且当遇到散列冲突时，性能不稳定，尽管二叉查找树的性能不稳定，但是在工程中，我们最常用的平衡二叉查找树的性能非常稳定，时间复杂度稳定在 O(logn)。
3. 笼统地来说，尽管散列表的查找等操作的时间复杂度是常量级的，但因为哈希冲突的存在，这个常量不一定比 logn 小，所以实际的查找速度可能不一定比 O(logn) 快。加上哈希函数的耗时，也不一定就比平衡二叉查找树的效率高。
4. 散列表的构造比二叉查找树要复杂，需要考虑的东西很多。比如散列函数的设计、冲突解决办法、扩容、缩容等。平衡二叉查找树只需要考虑平衡性这一个问题，而且这个问题的解决方案比较成熟、固定。
5. 为了避免过多的散列冲突，散列表装载因子不能太大，特别是基于开放寻址法解决冲突的散列表，不然会浪费一定的存储空间。