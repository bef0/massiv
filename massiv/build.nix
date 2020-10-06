{ mkDerivation, base, bytestring, data-default-class, deepseq
, doctest, exceptions, mersenne-random-pure64, primitive
, QuickCheck, random, scheduler, splitmix, stdenv, template-haskell
, unliftio-core, vector
}:
mkDerivation {
  pname = "massiv";
  version = "0.5.4.0";
  src = ./.;
  libraryHaskellDepends = [
    base bytestring data-default-class deepseq exceptions primitive
    scheduler unliftio-core vector
  ];
  testHaskellDepends = [
    base doctest mersenne-random-pure64 QuickCheck random splitmix
    template-haskell
  ];
  jailbreak = true;
  homepage = "https://github.com/lehins/massiv";
  description = "Massiv (Массив) is an Array Library";
  license = stdenv.lib.licenses.bsd3;
}
