module Main where

import System.IO
import System.Environment (getArgs)
import Data.Char (isPunctuation)
import Data.List (tails, isInfixOf) -- 'isInfixOf' usado para buscar os marcadores
import System.Random (randomRIO)
import qualified Data.Map.Strict as Map

-- ==========================================
-- 1. Definição de Tipos
-- ==========================================

type Token = String
type NGram = [Token] 
type MarkovMap = Map.Map NGram [Token] 

-- ==========================================
-- 2. Lógica Pura (Processamento e Modelo)
-- ==========================================

-- Função para remover Header e Footer do Gutenberg
extractBody :: String -> String
extractBody content = unlines bodyLines
  where
    allLines = lines content
    
    -- Definição dos marcadores padrão do Project Gutenberg
    -- Nota: usamos isInfixOf para pegar variações (ex: "START OF THIS PROJECT...")
    isStartLine line = "*** START OF THE PROJECT" `isInfixOf` line
    isEndLine line   = "*** END OF THE PROJECT"   `isInfixOf` line

    -- 1. Descarta o cabeçalho
    restAfterStart = case dropWhile (not . isStartLine) allLines of
        []     -> allLines  -- Se não achar o marcador, usa o texto original (fallback)
        (_:xs) -> xs        -- Descarta a linha do marcador e pega o resto

    -- 2. Descarta o rodapé
    bodyLines = takeWhile (not . isEndLine) restAfterStart

preprocess :: Char -> String
preprocess c
    -- Mantém hífens, apóstrofos e underscores colados na palavra (ex: guarda-chuva, d'água)
    | c `elem` "-'_"  = [c] 
    -- Separa qualquer outra pontuação (.,!?:;) com espaços para virarem tokens isolados
    | isPunctuation c = " " ++ [c] ++ " " 
    -- Mantém letras e números normais
    | otherwise       = [c]

tokenize :: String -> [Token]
tokenize rawText = words (concatMap preprocess rawText)

buildModel :: Int -> [Token] -> MarkovMap
buildModel n tokens = 
    let 
        -- Cria janelas deslizantes de tamanho N+1
        windows = filter (\w -> length w == n + 1) 
                $ map (take (n + 1)) (tails tokens)
        
        -- Separa em (Estado, Próxima_Palavra)
        -- Ex: ["eu", "amo", "cafe"] -> (["eu", "amo"], ["cafe"])
        mkPair w = (init w, [last w])
        pairs = map mkPair windows
    in 
        -- Agrupa ocorrências: se a chave repete, concatena as opções na lista
        Map.fromListWith (++) pairs

-- ==========================================
-- 3. Lógica Impura & Geração
-- ==========================================

randomChoice :: [a] -> IO a
randomChoice xs = do
    idx <- randomRIO (0, length xs - 1)
    return (xs !! idx)

-- Decide se o token deve "grudar" no anterior (sem espaço)
shouldAttach :: Token -> Bool
shouldAttach [] = False
shouldAttach (x:_) = x `elem` ".,;?!:)]}"

generateText :: MarkovMap -> NGram -> Int -> IO ()
generateText _ _ 0 = putStrLn "" -- Fim do limite de palavras
generateText model currentGram limit = do
    case Map.lookup currentGram model of
        Nothing -> do
            putStrLn " [Fim do caminho no modelo]"
            return ()
            
        Just possibilities -> do
            -- 1. Sorteia a próxima palavra
            nextWord <- randomChoice possibilities
            
            -- 2. Formata e Imprime
            let prefix = if shouldAttach nextWord then "" else " "
            putStr $ prefix ++ nextWord
            
            -- 3. Atualiza o estado (Drop 1 remove a palavra mais antiga)
            let newGram = drop 1 currentGram ++ [nextWord]
            
            -- 4. Recursão
            generateText model newGram (limit - 1)

-- ==========================================
-- 4. Main e Utilitários
-- ==========================================

-- Imprime a seed inicial formatada corretamente
printSeed :: NGram -> IO ()
printSeed [] = return ()
printSeed (x:xs) = do
    putStr x -- A primeira palavra nunca tem espaço antes
    mapM_ printRest xs 
  where
    printRest token = do
        let prefix = if shouldAttach token then "" else " "
        putStr $ prefix ++ token

main :: IO ()
main = do
    args <- getArgs
    
    -- CONFIGURAÇÃO CRÍTICA: Força UTF-8 para lidar com acentos (Português)
    hSetEncoding stdout utf8
    hSetEncoding stdin utf8

    case args of
        [fileName, nStr, sizeStr] -> do
            let n = read nStr :: Int
            let size = read sizeStr :: Int
            
            putStrLn $ ">> Lendo arquivo: " ++ fileName ++ "..."
            handle <- openFile fileName ReadMode
            hSetEncoding handle utf8
            content <- hGetContents handle
            
            -- 1. Limpeza do Header/Footer
            let cleanContent = extractBody content
            
            -- 2. Tokenização
            let tokens = tokenize cleanContent
            putStrLn $ ">> Tokens processados (após limpeza): " ++ show (length tokens)
            
            -- 3. Construção do Modelo
            putStrLn ">> Construindo Modelo de Markov..."
            let model = buildModel n tokens
            
            if Map.null model 
                then putStrLn "ERRO: O modelo está vazio. Verifique se o arquivo tem texto suficiente."
                else do
                    putStrLn $ ">> Modelo pronto. Estados distintos: " ++ show (Map.size model)
                    
                    -- Escolhe um estado inicial aleatório
                    startNode <- randomChoice (Map.keys model)
                    
                    putStrLn "\n================ GERANDO TEXTO ================"
                    printSeed startNode 
                    generateText model startNode size
                    putStrLn "\n==============================================="
            
            hClose handle

        _ -> putStrLn "Uso correto: ./generator <arquivo.txt> <ordem_N> <tamanho_texto>"