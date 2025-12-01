{
  description = "Ambiente de desenvolvimento Haskell - Markov Chain";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:nixos/nixpkgs/aca0bbe791c220f8360bd0dd8e9dce161253b341";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-old,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
          oldPkgs = import nixpkgs-old {inherit system;};
        });
  in {
    devShells = forEachSupportedSystem ({
      pkgs,
      oldPkgs,
    }: {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs;
          [
            clang-tools
            cabal-install
            wget # para baixar o dataset facilmente

            (ghc.withPackages (ps:
              with ps; [
                random
                containers
                text # Essencial para processamento de texto eficiente
              ]))

            haskell-language-server
          ]
          ++ (with oldPkgs; []);
      };
    });
  };
}