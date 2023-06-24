This is my hobby project to learn compiler implementation.

素朴な自作言語Ruccolaのコンパイラをセルフホストした  
https://qiita.com/sonota88/items/1e683276541cf1b87b76

See also: [selfhost/README.md](selfhost/README.md)


# Example

[examples/fibonacci.rcl](examples/fibonacci.rcl)

```ruby
#include ../selfhost/lib/std.rcl

def fib(n)
  case
  when (n < 0)
    _panic();
  when (n < 3)
    return n;
  else
    return fib(__sub(n, 2)) + fib(__sub(n, 1));
  end
end

def main()
  var n = 0;

  while (n < 21)
    print_i(n);
    putchar(C_SPC());
    print_i(fib(n));
    putchar(C_LF());

    n = n + 1;
  end
end
```
