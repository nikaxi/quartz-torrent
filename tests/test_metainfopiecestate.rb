#!/usr/bin/env ruby 
require 'fileutils'
require 'minitest/unit'
require 'minitest/autorun'
require 'quartz_torrent/metainfopiecestate'
require 'digest/sha1'

include QuartzTorrent

TestsDir = "tests"
TestDataDir = "tests/data"
TestDataTmpDir = "tests/data/tmp"

if ! File.directory?(TestDataTmpDir)
  FileUtils.mkdir TestDataTmpDir
end 

class TestMetainfoPieceState < MiniTest::Unit::TestCase
  def setup
  end

  def testWriting

    LogManager.setup { setLogfile "stdout" }
    LogManager.setLevel "metainfo_piece_state", :debug

    infoHash = Array.new(20).fill{ rand(256) }.pack "C*"
    # This metainfo will have two pieces
    state = MetainfoPieceState.new TestDataTmpDir, infoHash, 20000

    path = "#{TestDataTmpDir}/#{state.infoFileName}"
    FileUtils.rm path if File.exists? path
    
    piece1 = "abcdefgh" * 2048
    piece2 = "x" * (20000-16384)

    state.savePiece 0, piece1
    state.wait
    state.savePiece 1, piece2
    state.wait
    state.flush
    state.checkResults[0] # Get rid of save results.

    contents = File.read path
    assert_equal piece1 + piece2, contents

    id = state.readPiece 0
    state.wait
    result = state.checkResults[0]
    assert_equal piece1, result.data

    state.readPiece 1
    state.wait
    result = state.checkResults[0]
    assert_equal piece2, result.data
  end

  def testReading
    LogManager.setup { setLogfile "stdout" }
    LogManager.setLevel "metainfo_piece_state", :debug

    metainfo = QuartzTorrent::Metainfo.createFromFile("#{TestDataDir}/testtorrent.torrent")
    infoHash = Digest::SHA1.digest( metainfo.info.bencode )

    # This metainfo will have one piece
    state = MetainfoPieceState.new TestDataTmpDir, infoHash, nil, metainfo.info
    
    state.readPiece 0
    state.wait
    result = state.checkResults[0]
    assert_equal metainfo.info.bencode, result.data
  end
  
  def testAlreadyExists
    LogManager.setup { setLogfile "stdout" }
    LogManager.setLevel "metainfo_piece_state", :debug

    metainfo = QuartzTorrent::Metainfo.createFromFile("#{TestDataDir}/testtorrent.torrent")
    infoHash = Digest::SHA1.digest( metainfo.info.bencode )

    infoFileName = MetainfoPieceState.generateInfoFileName(infoHash)
  
    path = "#{TestDataTmpDir}/#{infoFileName}"
    FileUtils.rm path if File.exists? path

    File.open(path, "w") do |file|
      file.write metainfo.info.bencode
    end

    # Check that if the info file exists, MetainfoPieceState detects that.
    assert MetainfoPieceState.downloaded TestDataTmpDir, infoHash
  end

end


