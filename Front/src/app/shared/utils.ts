export class Utils {

    static getMaskCnpj() {
      return [/\d/, /\d/, '.', /\d/, /\d/, /\d/, '.', /\d/, /\d/, /\d/, '/', /\d/, /\d/, /\d/, /\d/, '-', /\d/, /\d/];
    }

    static removeSpecialCharacters(str) {
      //TODO: Today it is used only to CNPJ. If necessary, expand to remove other characters
      return str.replace(/-/g, '').replace(/\./g, '').replace('/', '').replace(/_/g, '')
    }  

    static isValidHash(text) {
      if (!text) return false;
      if (text.length<2) return false;
      let prefixHash = text.substr(0,2);
      if (prefixHash!="0x") return false;
      text = text.substr(2);
      let isHash = /^[\da-f]+$/.test(text);
      if (isHash && text.length && text.length==64) {
        return true;
      }
      return false;
    }
    
    static completarCnpjComZero(cnpj){
        return ("00000000000000" + cnpj).slice(-14)
     }

     static completarContratoComZero(cnpj){
      return ("00000000" + cnpj).slice(-8)
   }

     static criarAlertasAvisoConfirmacao(tx, web3Service, bnAlertsService, warningMsg, confirmationMsg, zoneUpdate) {        
          bnAlertsService.criarAlerta("info", "Aviso", warningMsg, 5);
          console.log(warningMsg);

          web3Service.registraWatcherEventosLocal(tx.hash, function () {
              bnAlertsService.criarAlerta("info", "Confirmação", confirmationMsg, 5);
              console.log(confirmationMsg);

              zoneUpdate.run(() => {});
          });
     }

     static criarAlertaErro( bnAlertsService, errorMsg, error) {
         bnAlertsService.criarAlerta("error", "Erro", errorMsg, 5);
         console.log(errorMsg);
         console.log(error);
     }

     static criarAlertaAcaoUsuario( bnAlertsService, userMsg ) {
        bnAlertsService.criarAlerta("info", "", userMsg, 5);
        console.log(userMsg);
     }
      
}