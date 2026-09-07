type Props = {
  visible: boolean
}

export function PhoneCall({ visible }: Props) {
  if (!visible) return null

  return (
    <div className="phone-call">
      <div className="phone-call__shell">
        <span className="phone-call__speaker" />
        <div>
          <p>Chamada Desconhecida</p>
          <h2>Solicitação especial de frete</h2>
          <span>Y aceitar / N recusar</span>
        </div>
      </div>
    </div>
  )
}
