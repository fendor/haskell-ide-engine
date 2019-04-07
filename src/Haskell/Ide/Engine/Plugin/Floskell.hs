{-# LANGUAGE OverloadedStrings #-}

module Haskell.Ide.Engine.Plugin.Floskell
  ( floskellDescriptor
  )
where

import           Control.Monad.IO.Class         (liftIO)
import           Data.Aeson                     (Value (Null))
import qualified Data.ByteString.Lazy           as BS
import qualified Data.Text                      as T
import qualified Data.Text.Encoding             as T
import           Data.Maybe
import           Floskell
import           Haskell.Ide.Engine.MonadTypes
import           Haskell.Ide.Engine.PluginUtils

floskellDescriptor :: PluginId -> PluginDescriptor
floskellDescriptor plId = PluginDescriptor
  { pluginId                 = plId
  , pluginName               = "Floskell"
  , pluginDesc               = "A flexible Haskell source code pretty printer."
  , pluginCommands           = []
  , pluginCodeActionProvider = Nothing
  , pluginDiagnosticProvider = Nothing
  , pluginHoverProvider      = Nothing
  , pluginSymbolProvider     = Nothing
  , pluginFormattingProvider = Just provider
  }

provider :: FormattingProvider
provider uri typ _opts = do
    root <- getRootPath
    config <- liftIO $ findConfigOrDefault (fromMaybe "" root)
    mContents <- readVFS uri
    case mContents of
      Nothing -> return $ IdeResultFail (IdeError InternalError "File was not open" Null)
      Just contents ->
        let (range, selectedContents) = case typ of
              FormatDocument -> (fullRange contents, contents)
              FormatRange r  -> (r, extractRange r contents)
            result = reformat config (uriToFilePath uri) (BS.fromStrict (T.encodeUtf8 selectedContents))
        in  case result of
              Left  err -> return $ IdeResultFail (IdeError PluginError (T.pack err) Null)
              Right new -> return $ IdeResultOk [TextEdit range (T.decodeUtf8 (BS.toStrict new))]



findConfigOrDefault :: FilePath -> IO AppConfig
findConfigOrDefault file = do
  mbConf <- findAppConfigIn file
  case mbConf of
    Just confFile -> readAppConfig confFile
    Nothing ->
      let gibiansky = head (filter (\s -> styleName s == "gibiansky") styles)
      in return $ defaultAppConfig { appStyle = gibiansky }
