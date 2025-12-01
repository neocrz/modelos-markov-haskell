# modelos-markov-haskell
```
git clone https://github.com/neocrz/modelos-markov-haskell
cd modelos-markov-haskell
nix develop .
wget https://www.gutenberg.org/ebooks/54829.txt.utf-8 -O dataset.txt
ghc Main.hs -o generator
./generator dataset.txt 2 200
```
- Dataset: ``
