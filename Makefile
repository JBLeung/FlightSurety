server:
	ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" -a 50
reset:
	rm -Rf ./build; truffle migrate --reset; npm test;
clean:
	rm -Rf ./build;rm -Rf ./bin;