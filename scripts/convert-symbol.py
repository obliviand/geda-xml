#!/usr/bin/python

import io
import re

class SymbolVersion():
	def __init__(self, datecode=None, version=None):
		self.__datecode = datecode
		self.__version = version

	def __str__(self):
		return "v " + self.__datecode + " " + self.__version

	def getdatecode(self):
		return self.__datecode

	def getversion(self):
		return self.__version

	@staticmethod
	def fromstr(str):
		this = None
		m = re.search('^v ([0-9]*) ([0-9]*)', str)
		if m <> None and len(m.groups()) == 2:
			this = SymbolVersion(m.group(1), m.group(2))
		return this

class SymbolReader(io.IOBase):

	class SymbolReaderException(Exception):
		def __init__(self, value):
			self.value = value
		def __str__(self):
			return repr(self.value)

	def __init__(self, stream):
		assert isinstance(stream, io.IOBase)
		stream.readable()
		self.__stream = stream
		self.__lines = self.__stream.readlines()
		self.__stream.seek(0)

	def getsymbolversion(self):
		''' @return A list of parameters that the "v" command contains '''
		v = list()
		for line in self.__lines:
			m = re.search('^v .*', line)
			if m <> None:
				v.append(m.group(0))

		# Make sure there is only one 'v' command
		if len(v) <> 1:
			raise self.SymbolReaderException("More than one version command found in symbol file")

		return SymbolVersion.fromstr(v[0])

	def readable(self):
		return self.__stream.readable()

	def readline(self, limit=None):
		return self.__stream.readline(limit)

	def readlines(self, hint=None):
		return self.__stream.readlines(hint)

def main():
	file = io.FileIO('../examples/7400-1.sym', 'rb')
	symbol = SymbolReader(file)

	print symbol.readable()
	print symbol.writable()
	print symbol.seekable()

	print symbol.getsymbolversion().getversion()
	print symbol.getsymbolversion().getdatecode()

if __name__ == "__main__":
	main()
