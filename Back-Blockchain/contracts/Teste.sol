pragma solidity ^0.5.0;

/*
    //businessContractId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;



//Cada contrato

//mantem balances
//(RBBid => (specificHash => amount)
mapping (uint => mapping (bytes32 => uint)) public rbbBalances;

//businessContractId => amount)
mapping (uint => uint) public totalSupply; (quanto já emitiu e ainda n queimou)
//businessContractId => amount)
mapping (uint => uint) public usedSupply; (quanto já alocou e ainda n queimou)


allocate
    * verifica se tem totalSupply - usedSupply para allocar
    * atualiza valores dessas duas variaveis
    * chama metodo da superclasse do token especifico para incrementar saldo

transfer
    * na superclasse
    * verifica o sender
    * chama RBB_Token para logar transacao ?

deallocate
    * queima totalSupply e usedSupply

mint e burn
    * nas subclasses desde que nao ultrapasse total_supply

*/