import { createContext, useContext, useEffect, useState } from "react";
import { nuicallback } from "../utils/nuicallback";

const ConfigCtx = createContext(null);

const ConfigProvider = ({ children }) => {
  const [config, setConfig] = useState({
    Scenes: [
      {
        id: "casino",
        label: "CASINO",
      },
      {
        id: "zancudo",
        label: "ZANCUDO",
      },
      {
        id: "zancudo",
        label: "ZANCUDO",
      },
      {
        id: "zancudo",
        label: "ZANCUDO",
      },
      {
        id: "zancudo",
        label: "ZANCUDO",
      },
      {
        id: "zancudo",
        label: "ZANCUDO",
      },
    ],
    Lang: {
      START: "INICIAR",
      CREDIT: "CRÉDITOS",
      create: "CRIAR",
      character: "PERSONAGEM",
      description: "Preencha os dados do personagem com um nome e uma data de nascimento realistas",
      firstName: "NOME",
      lastName: "SOBRENOME",
      male: "Masculino",
      female: "Feminino",
      dob: "DATA DE NASCIMENTO",
      year: "Ano",
      day: "Dia",
      month: "Mês",
      nationality: "NACIONALIDADE",
      searchcountry: "Buscar país",
      done: "Concluir",
      esc: "ESC",
      back: "VOLTAR",
      EXIT: "SAIR",
      exit: "SAIR",
      enter: "ENTRAR",
      dev: "@Desenvolvido por",
      afterlife: "AfterLife Studios",
      exitgame: "SAIR DO JOGO",
      exitdescription: "Tem certeza de que deseja sair do jogo?",
      delete: "EXCLUIR PERSONAGEM",
      deletedescription: "Tem certeza de que deseja excluir este personagem?",
      hold: "Segure",
      loadingsession: "CARREGANDO SESSÃO",
      loadingscene: "CARREGANDO CENA",
      loadingcharacter: "CARREGANDO PERSONAGEM",
    },
    credits: [
      {
        title: "Diretor",
        description: "JGUsman",
      },
      {
        title: "Desenvolvedor principal",
        description: "JGUsman",
      },
      {
        title: "Desenvolvedor da interface",
        description: "Hammas (my big B)",
      },
      {
        title: "Designer da interface",
        description: "ofc me again",
      },
      {
        title: "Créditos",
        description: "AfterLife Studios",
      },
    ],
    maxdob: 2005,
    mindob: 1950,
  });

  useEffect(() => {
    nuicallback("getConfig").then((data) => setConfig(data));
  }, []);

  return (
    <ConfigCtx.Provider value={{ config, setConfig }}>
      {children}
    </ConfigCtx.Provider>
  );
};

export default ConfigProvider;

export const useConfig = () => useContext(ConfigCtx);
