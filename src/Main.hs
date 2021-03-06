module Main where

import HGB.Types
import HGB.CPU
import HGB.MMU
import HGB.Cartridge
import Text.Groom
import System.Environment (getArgs)
import Control.Lens ((^.))
import Control.Monad.State (execState)
import qualified Data.Vector.Unboxed as V
import Data.Word (Word8)
import HGB.Lens
import           Debug.Trace
import           System.IO

-- Debug
import Data.List (intercalate)
import HGB.GPU

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> putStrLn "usage : hgb file.gb"
    _  -> do
      vm' <- loadRom . head $ args
      case vm' of
        Left msg   -> putStrLn msg
        Right vm'' -> do
--          putStrLn . groom $ vm'' ^. cartridge
          vm''' <- runStep' vm''
          runStep vm'''

runStep :: Vm -> IO ()
runStep oldVm = do
  -- Wait from user input
  getLine
  -- Compute next step
  newVM <- return . execState exec $ oldVm
  -- Display CPU
  putStrLn . groom $ newVM ^. cpu
  putStrLn $ "lZ:" ++ (show $ newVM ^. cpu . lZf)
  putStrLn $ "lN:" ++ (show $ newVM ^. cpu . lNf)
  putStrLn $ "lH:" ++ (show $ newVM ^. cpu . lHf)
  putStrLn $ "lC:" ++ (show $ newVM ^. cpu . lCf)
  -- Loop
  newVM `seq` runStep newVM

runStep' :: Vm -> IO Vm
runStep' oldVm = do
  newVM <- return . execState exec $ oldVm
  if (newVM ^. pc) >= 0x94
    then return newVM
    else newVM `seq` runStep' newVM
--  trace (show $ (newVM ^. registers . lZf, newVM ^. gpuLine)) return ()
--  putStr . show $ (newVM ^. registers, newVM ^. cpuClock)
--  putStr "\r"
--  hFlush stdout

runStep'' :: Int -> Vm -> IO ()
runStep'' i oldVm = do
  newVM <- return . execState exec $ oldVm
  case i of
    400000 -> do
--      debugDisp (newVM ^. vram)
      let mmu' = newVM ^. mmu
--      putStr . show $ newVM ^. registers
--      putStrLn . groom $ newVM ^. cpu
--      putStrLn . groom $ newVM ^. gpu
      putStrLn (intercalate "\n" . showRenderedMem $ mmu')
--      putStrLn . groom $ newVM ^. vram
--      putStr . show $ (newVM ^. registers, newVM ^. cpuClock)
--      putStr "\r"
      newVM `seq` runStep'' 0 newVM
    _ ->  newVM `seq` runStep'' (i+1) newVM


perfCheck :: Int -> Vm -> IO ()
perfCheck i oldVm = do
  newVM <- return . execState exec $ oldVm
  case i of
    53000 -> do
      return ()
    _ ->  newVM `seq` perfCheck (i+1) newVM

-- | Display the memory (debug purpose)
debugDisp :: V.Vector Word8 -> IO ()
debugDisp vec = do
  --showLine 0
  putStrLn . groom $ vec
  putStrLn ""
  where
    v = V.slice 0x800 (0x9BFF - 0x9800 + 1) $ vec
    showLine 32 = return ()
    showLine i = showChar i 0 >> putStrLn "" >> showLine (i+1)
    showChar _ 32 = return ()
    showChar i j = (putStr . show $ v V.! (i*32 + j)) >> showChar i (j + 1)
