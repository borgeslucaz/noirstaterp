import './styles.css';

interface ModalProps {
  title: string;
  description: string;
  accept: string;
  decline: string;
  handleAccept: () => Promise<void> | void;
  handleDecline: () => Promise<void> | void;
}

const Modal = ({ title, description, accept, decline, handleAccept, handleDecline }: ModalProps) => {
  return (
    <div className="modal-wrapper">
      <p>{title}</p>
      <span>{description}</span>
      <div className="modal-buttons">
        <button type="button" onClick={handleAccept}>
          {accept}
        </button>
        <button type="button" onClick={handleDecline}>
          {decline}
        </button>
      </div>
    </div>
  );
};

export default Modal;
